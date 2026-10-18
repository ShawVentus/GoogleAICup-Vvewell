#!/usr/bin/env python3
"""Windows BLE GUI for vvewell-robot. Install once: py -m pip install bleak"""
import asyncio, json, queue, threading, tkinter as tk
from tkinter import ttk, messagebox
from bleak import BleakClient, BleakScanner

SERVICE_UUID="d6f00001-9a1a-4f8d-a7fd-2e3b2e819001"
RX_UUID="d6f00002-9a1a-4f8d-a7fd-2e3b2e819001"
TX_UUID="d6f00003-9a1a-4f8d-a7fd-2e3b2e819001"

class LoopThread:
    def __init__(self):
        self.loop=asyncio.new_event_loop()
        threading.Thread(target=self._run,daemon=True).start()
    def _run(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()
    def submit(self,coro): return asyncio.run_coroutine_threadsafe(coro,self.loop)

class App(tk.Tk):
    def __init__(self):
        super().__init__(); self.title("vvewell-robot BLE Controller"); self.geometry("700x600")
        self.loop, self.client, self.devices, self.events, self.seq = LoopThread(), None, [], queue.Queue(), 1
        self.angle=tk.IntVar(value=90); self.status=tk.StringVar(value="Click Scan. No Windows pairing is required.")
        f=ttk.Frame(self,padding=12); f.pack(fill="both",expand=True)
        ttk.Button(f,text="Scan BLE",command=self.scan).pack(anchor="w")
        self.list=tk.Listbox(f,height=7); self.list.pack(fill="x",pady=6)
        ttk.Button(f,text="Connect selected",command=self.connect).pack(anchor="w")
        e=ttk.LabelFrame(f,text="Expressions",padding=8); e.pack(fill="x",pady=10)
        for i,n in enumerate(("blue_upper","blue_middle","blue_lower","yellow_upper","yellow_middle","yellow_lower")):
            ttk.Button(e,text="{} {}".format(i+1,n),command=lambda x=n:self.send("expression",name=x)).grid(row=i//3,column=i%3,padx=3,pady=3,sticky="ew")
        ttk.Button(e,text="Off",command=lambda:self.send("expression",name="off")).grid(row=2,column=0,padx=3,pady=3)
        s=ttk.LabelFrame(f,text="SG90 servo",padding=8); s.pack(fill="x")
        ttk.Scale(s,from_=0,to=180,orient="horizontal",variable=self.angle).pack(fill="x")
        ttk.Button(s,text="Set angle",command=lambda:self.send("servo",angle=self.angle.get())).pack(side="left",pady=6)
        ttk.Button(s,text="Servo off",command=lambda:self.send("servo_off")).pack(side="left",padx=6,pady=6)
        ttk.Button(f,text="Status",command=lambda:self.send("status")).pack(anchor="w",pady=8)
        self.log=tk.Text(f,height=12,state="disabled"); self.log.pack(fill="both",expand=True)
        ttk.Label(f,textvariable=self.status).pack(anchor="w",pady=5); self.after(100,self.drain)
    def logline(self,x):
        self.log.configure(state="normal"); self.log.insert("end",x+"\n"); self.log.see("end"); self.log.configure(state="disabled")
    def background(self,coro,done=None):
        def wait():
            try:self.events.put((done,self.loop.submit(coro).result()))
            except Exception as e:self.events.put((None,e))
        threading.Thread(target=wait,daemon=True).start()
    def scan(self):
        self.status.set("Scanning BLE devices for 5 seconds..."); self.logline("SCAN started")
        self.background(self._scan(),self.scanned)
    async def _scan(self): return await BleakScanner.discover(timeout=5,return_adv=True)
    def scanned(self,result):
        self.devices=[]; self.list.delete(0,"end")
        for address, (device, adv) in result.items():
            name = device.name or adv.local_name or "(no advertised name)"
            service_uuids = [uuid.lower() for uuid in (adv.service_uuids or [])]
            marker = "  <-- K3 service" if SERVICE_UUID.lower() in service_uuids else ""
            self.devices.append(device)
            self.list.insert("end", "{}  {}  RSSI:{}{}".format(name, address, adv.rssi, marker))
        self.status.set("Found {} BLE device(s); select vvewell-robot manually.".format(len(self.devices)))
        self.logline("SCAN completed: {} BLE device(s)".format(len(self.devices)))
    def connect(self):
        selected=self.list.curselection()
        if not selected:return messagebox.showwarning("BLE","Select vvewell-robot first.")
        self.status.set("Connecting..."); self.logline("CONNECT requested")
        self.background(self._connect(self.devices[selected[0]]),self.connected)
    async def _connect(self,device):
        self.client=BleakClient(device); await self.client.connect(); await self.client.start_notify(TX_UUID,self.notify); return device.address
    def connected(self,address): self.status.set("Connected: {}".format(address)); self.logline("CONNECTED")
    def notify(self,_sender,data): self.events.put((self.response,bytes(data)))
    def send(self,cmd,**kwargs):
        if not self.client:return messagebox.showwarning("BLE","Connect first.")
        payload={"id":self.seq,"cmd":cmd}; payload.update(kwargs); self.seq+=1; self.background(self._send(payload))
    async def _send(self,payload):
        await self.client.write_gatt_char(RX_UUID,(json.dumps(payload)+"\n").encode(),response=False)
        return payload
    def response(self,data): self.logline(data.decode("utf-8",errors="replace").strip()); self.status.set("Response received.")
    def drain(self):
        try:
            while True:
                callback,value=self.events.get_nowait()
                if callback: callback(value)
                else: self.status.set("Error: {}".format(value)); self.logline("ERROR: {}".format(value))
        except queue.Empty:pass
        self.after(100,self.drain)

if __name__=="__main__": App().mainloop()
