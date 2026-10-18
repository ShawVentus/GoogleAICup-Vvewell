import UIKit
@preconcurrency import Vision

extension SymptomChatViewController {

    // MARK: - Attachments

    func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        present(picker, animated: true)
    }

    func presentPDFPicker() {
        let picker = UIDocumentPickerViewController(documentTypes: ["com.adobe.pdf"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func prepareImageAttachment(_ image: UIImage, suggestedName: String) {
        attachmentTask?.cancel()
        let id = beginAttachmentPreparation(kind: .image, displayName: suggestedName)

        attachmentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let attachment = try await self.makeImageAttachment(from: image, suggestedName: suggestedName)
                await MainActor.run {
                    self.updatePendingAttachment(id: id, state: .ready(id: id, attachment: attachment))
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self.updatePendingAttachment(
                        id: id,
                        state: .failed(id: id, kind: .image, name: suggestedName, message: error.localizedDescription.isEmpty ? t(.symptomChatAttachmentImageFailed) : error.localizedDescription)
                    )
                }
            }
        }
    }

    func preparePDFAttachment(from url: URL) {
        attachmentTask?.cancel()
        let displayName = url.lastPathComponent.isEmpty ? t(.symptomChatAttachmentDefaultPDFName) : url.lastPathComponent
        let id = beginAttachmentPreparation(kind: .pdf, displayName: displayName)

        attachmentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let attachment = try await self.makePDFAttachment(from: url)
                await MainActor.run {
                    self.updatePendingAttachment(id: id, state: .ready(id: id, attachment: attachment))
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self.updatePendingAttachment(
                        id: id,
                        state: .failed(id: id, kind: .pdf, name: displayName, message: error.localizedDescription.isEmpty ? t(.symptomChatAttachmentPdfFailed) : error.localizedDescription)
                    )
                }
            }
        }
    }

    private func beginAttachmentPreparation(kind: PendingAttachmentKind, displayName: String) -> UUID {
        let id = UUID()
        pendingAttachments.append(.processing(id: id, kind: kind, name: displayName))
        return id
    }

    private func updatePendingAttachment(id: UUID, state: PendingAttachmentState) {
        guard let index = pendingAttachments.firstIndex(where: { $0.id == id }) else { return }
        pendingAttachments[index] = state
    }

    func clearPendingAttachments() {
        pendingAttachments.removeAll()
        attachmentTask?.cancel()
        attachmentTask = nil
    }

    func refreshAttachmentPreviewStack() {
        attachmentPreviewStack.removeAllArrangedSubviews()
        guard !pendingAttachments.isEmpty else {
            attachmentPreviewStack.isHidden = true
            return
        }

        for state in pendingAttachments {
            let chip = ComposerAttachmentChipView()
            chip.configure(with: state)
            chip.onRemove = { [weak self] id in
                self?.pendingAttachments.removeAll { $0.id == id }
            }
            attachmentPreviewStack.addArrangedSubview(chip)
        }

        attachmentPreviewStack.isHidden = false
        scrollToBottom()
    }

    private func makeImageAttachment(from image: UIImage, suggestedName: String) async throws -> PreparedAttachment {
        guard let imageData = image.jpegData(compressionQuality: 0.82) else {
            throw APIError.analysisFailed(t(.symptomChatAttachmentImageFailed))
        }

        let textContent: String
        do {
            let result = try await remoteService.uploadOcrReport(imageData: imageData)
            textContent = trimmedAttachmentText(attachmentText(from: result))
        } catch {
            let recognizedText = try await recognizeText(in: image)
            textContent = trimmedAttachmentText(recognizedText)
        }

        guard !textContent.isEmpty else {
            throw APIError.analysisFailed(t(.symptomChatAttachmentImageFailed))
        }

        return PreparedAttachment(
            kind: .image,
            displayName: suggestedName,
            summary: condensed(textContent, limit: 120),
            payload: AssistantAttachmentPayload(
                kind: "image",
                name: suggestedName,
                mimeType: PendingAttachmentKind.image.mimeType,
                textContent: textContent
            )
        )
    }

    private func makePDFAttachment(from url: URL) async throws -> PreparedAttachment {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = CGPDFDocument(url as CFURL) else {
            throw APIError.analysisFailed(t(.symptomChatAttachmentFailed))
        }

        var segments: [String] = []
        let pageLimit = min(document.numberOfPages, 5)
        for pageIndex in 1...pageLimit {
            guard let page = document.page(at: pageIndex),
                  let rendered = renderPDFPage(page) else { continue }
            let recognized = try await recognizeText(in: rendered)
            if !recognized.trimmedForChat.isEmpty {
                segments.append(recognized)
            }
        }

        let textContent = trimmedAttachmentText(segments.joined(separator: "\n\n"))
        guard !textContent.isEmpty else {
            throw APIError.analysisFailed(t(.symptomChatAttachmentPdfEmpty))
        }

        let name = url.lastPathComponent.isEmpty ? t(.symptomChatAttachmentDefaultPDFName) : url.lastPathComponent
        return PreparedAttachment(
            kind: .pdf,
            displayName: name,
            summary: condensed(textContent, limit: 120),
            payload: AssistantAttachmentPayload(
                kind: "pdf",
                name: name,
                mimeType: PendingAttachmentKind.pdf.mimeType,
                textContent: textContent
            )
        )
    }

    private func attachmentText(from result: OcrReportAPIResponse) -> String {
        var lines: [String] = []
        lines.append(String(format: t(.symptomChatAttachmentLineReportTypeFormat), result.reportType))
        if let hospital = result.hospital, !hospital.trimmedForChat.isEmpty {
            lines.append(String(format: t(.symptomChatAttachmentLineHospitalFormat), hospital))
        }
        if let reportDate = result.reportDate, !reportDate.trimmedForChat.isEmpty {
            lines.append(String(format: t(.symptomChatAttachmentLineDateFormat), reportDate))
        }
        if let conclusion = result.conclusion, !conclusion.trimmedForChat.isEmpty {
            lines.append(String(format: t(.symptomChatAttachmentLineConclusionFormat), conclusion))
        }
        if let detailText = result.detailText, !detailText.trimmedForChat.isEmpty {
            lines.append(detailText)
        } else if !result.items.isEmpty {
            lines.append(t(.symptomChatAttachmentItemsHeader))
            for item in result.items.prefix(20) {
                let name = item["name"] ?? t(.symptomChatAttachmentItemFallbackName)
                let value = item["value"] ?? ""
                let reference = item["reference_range"] ?? item["reference"] ?? ""
                let abnormal = item["is_abnormal"] == "true" ? t(.symptomChatAttachmentItemAbnormalSuffix) : ""
                lines.append(String(format: t(.symptomChatAttachmentItemLineFormat), name, value, reference, abnormal))
            }
        }
        return lines.joined(separator: "\n")
    }

    private func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw APIError.analysisFailed(t(.symptomChatAttachmentFailed))
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = [
                currentRecognitionLanguage(),
                "en-US",
                "zh-Hans",
                "ar-SA",
            ]

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func renderPDFPage(_ page: CGPDFPage) -> UIImage? {
        let bounds = page.getBoxRect(.mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = min(2.0, 1400.0 / max(bounds.width, bounds.height))
        let targetSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: targetSize))
        context.saveGState()
        context.translateBy(x: 0, y: targetSize.height)
        context.scaleBy(x: scale, y: -scale)
        context.drawPDFPage(page)
        context.restoreGState()
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func currentRecognitionLanguage() -> String {
        LocaleManager.shared.current.ocrRecognitionLanguageIdentifier
    }

    private func trimmedAttachmentText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard normalized.count > 6000 else { return normalized }
        let endIndex = normalized.index(normalized.startIndex, offsetBy: 6000)
        return String(normalized[..<endIndex]) + "\n\n[truncated]"
    }

    private func condensed(_ text: String, limit: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard normalized.count > limit else { return normalized }
        let endIndex = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<endIndex]) + "…"
    }

    func makeHistoryMessage(requestText: String, attachments: [AssistantAttachmentPayload]) -> String {
        guard !attachments.isEmpty else { return requestText }
        let attachmentText = attachments.map {
            "[Attachment: \($0.name) | \($0.mimeType)]\n\($0.textContent)"
        }.joined(separator: "\n\n")
        return "\(requestText)\n\n\(attachmentText)"
    }
}
