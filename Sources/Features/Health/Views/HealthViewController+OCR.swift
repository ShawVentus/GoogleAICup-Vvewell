import UIKit

extension HealthViewController {

    // MARK: - OCR

    func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        present(picker, animated: true)
    }

    func runMockOCR(image: UIImage) {
        ocrLoadingLabel.text = t(.healthProfileOcrUploading)
        ocrLoadingLabel.isHidden = false
        ocrHistoryStack.isHidden = true
        uploadReportButton.isEnabled = false

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            showOcrFailureState()
            return
        }

        Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await remoteService.uploadOcrReport(imageData: imageData)
                let localFallbackReport = try self.makeLocalFallbackReport(from: response, imageData: imageData)

                await MainActor.run {
                    OcrReportRepository.shared.save(localFallbackReport)
                    self.ocrLoadingLabel.isHidden = true
                    self.ocrHistoryStack.isHidden = false
                    self.uploadReportButton.isEnabled = true
                    self.refreshOcrHistory()
                }
            } catch {
                await MainActor.run {
                    self.showOcrFailureState()
                }
            }
        }
    }

    private func makeLocalFallbackReport(from response: OcrReportAPIResponse, imageData: Data) throws -> OcrReport {
        let filename = "\(UUID().uuidString).jpg"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imgURL = docs.appendingPathComponent(filename)
        try imageData.write(to: imgURL, options: .atomic)

        let parsedReportDate: Date = {
            guard let raw = response.reportDate, !raw.isEmpty else { return Date() }
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: raw) { return date }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: raw) ?? Date()
        }()

        return OcrReport(
            id: UUID().uuidString,
            date: parsedReportDate,
            imageLocalPath: filename,
            source: .device,
            items: response.items.map { item in
                OcrReport.OcrItem(
                    name: item["name"] ?? "",
                    value: item["value"] ?? "",
                    reference: item["reference_range"] ?? item["reference"] ?? "",
                    isAbnormal: item["is_abnormal"] == "true"
                )
            }
        )
    }

    private func showOcrFailureState() {
        ocrLoadingLabel.text = t(.healthProfileOcrFailed)
        ocrLoadingLabel.isHidden = false
        ocrHistoryStack.isHidden = false
        refreshOcrHistory()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.ocrLoadingLabel.text = t(.healthProfileOcrUploading)
            self.ocrLoadingLabel.isHidden = true
            self.uploadReportButton.isEnabled = true
        }
    }
}
