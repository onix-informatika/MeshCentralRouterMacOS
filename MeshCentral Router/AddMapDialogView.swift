//
//  SettingsDialogView.swift
//  MeshCentral Router
//
//  Created by Default on 12/23/20.
//

import SwiftUI
import Combine

struct AppMapDialogView: View {
    var relay:Bool
    var devicesView:DevicesView?
    @State var name:String = ""
    @State var localPortStr:String = "0"
    @State var meshid:String = ""
    @State var nodeid:String = ""
    @State var remoteIp:String = ""
    @State var remotePortStr:String = "443"
    @State var usage:String = "HTTPS"
    @State var usageEx:String = "HTTPS"
    
    init (devicesView:DevicesView?, device:Device?, relay:Bool) {
        self.devicesView = devicesView
        self.relay = relay
        if (device == nil) {
            let dev:Device? = getFirstValidDevice()
            if (dev != nil) {
                _meshid = State(wrappedValue: dev!.meshid)
                _nodeid = State(wrappedValue: dev!.id)
            }
        } else {
            _meshid = State(wrappedValue: device!.meshid)
            _nodeid = State(wrappedValue: device!.id)
        }
    }
    
    func getFirstValidDevice() -> Device? {
        guard let mc = mc else { return nil }
        let devicesByGroup = buildOnlineDevicesByGroup(mc: mc)
        for grp:DeviceGroup in mc.deviceGroups {
            if let devices = devicesByGroup[grp.id], let dev = devices.first { return dev }
        }
        return nil
    }

    private func buildOnlineDevicesByGroup(mc:MeshCentralServer) -> [String:[Device]] {
        var devicesByGroup:[String:[Device]] = [:]
        devicesByGroup.reserveCapacity(mc.deviceGroups.count)
        for dev:Device in mc.devices {
            if ((dev.conn & 1) != 0) {
                devicesByGroup[dev.meshid, default: []].append(dev)
            }
        }
        return devicesByGroup
    }

    private func validDeviceGroups(mc:MeshCentralServer) -> [DeviceGroup] {
        let devicesByGroup = buildOnlineDevicesByGroup(mc: mc)
        return mc.deviceGroups.filter { devicesByGroup[$0.id]?.isEmpty == false }
    }

    private func validDevices(mc:MeshCentralServer, meshid:String) -> [Device] {
        return mc.devices.filter { (($0.meshid == meshid) && (($0.conn & 1) != 0)) }
    }
    
    private func normalizeSelectedDevice(mc:MeshCentralServer, meshid:String) {
        let devices = validDevices(mc: mc, meshid: meshid)
        if (devices.contains { $0.id == nodeid }) { return }
        nodeid = devices.first?.id ?? ""
    }

    private func deviceGroupPicker(mc:MeshCentralServer) -> some View {
        let groups = validDeviceGroups(mc: mc)
        return Picker("", selection: $meshid) {
            ForEach(groups, id: \.id) { deviceGroup in
                Text(deviceGroup.name).tag(deviceGroup.id)
            }
        }.labelsHidden().frame(width: 200)
            .onAppear {
                normalizeSelectedDevice(mc: mc, meshid: meshid)
            }
            .onChange(of: meshid) { newMeshId in
                normalizeSelectedDevice(mc: mc, meshid: newMeshId)
            }
    }

    private func devicePicker(mc:MeshCentralServer) -> some View {
        let devices = validDevices(mc: mc, meshid: meshid)
        return Picker("", selection: $nodeid) {
            ForEach(devices, id: \.id) { device in
                Text(device.name).tag(device.id)
            }
        }.labelsHidden().frame(width: 200)
    }
    
    var body: some View {
        VStack() {
            VStack(alignment: .leading) {
                HStack() {
                    Text("Name").frame(width: 100, alignment: .leading)
                    Spacer()
                    TextField("", text: $name).frame(width: 200).onExitCommand(perform: { name = "" })
                }
                HStack() {
                    Text("Local Port").frame(width: 100, alignment: .leading)
                    Spacer()
                    TextField("", text: $localPortStr).multilineTextAlignment(.trailing).frame(width: 200).onExitCommand(perform: { localPortStr = "0" })
                }
                HStack() {
                    Text("Device Group").frame(width: 100, alignment: .leading)
                    Spacer()
                    if let mc = mc {
                        deviceGroupPicker(mc: mc)
                    }
                }
                HStack() {
                    Text("Device").frame(width: 100, alignment: .leading)
                    Spacer()
                    if let mc = mc {
                        devicePicker(mc: mc)
                    }
                }
                HStack() {
                    Text("Protocol").frame(width: 100, alignment: .leading)
                    Spacer()
                    Picker("", selection: $usage) {
                        Text("Custom").tag("")
                        Text("HTTP").tag("HTTP")
                        Text("HTTPS").tag("HTTPS")
                        Text("SSH").tag("SSH")
                    }.labelsHidden().frame(width: 200).onReceive([self.usage].publisher.first()) { value in
                        if (value != usageEx) {
                            usageEx = value;
                            if (value == "HTTP") { remotePortStr = "80" }
                            if (value == "HTTPS") { remotePortStr = "443" }
                            if (value == "SSH") { remotePortStr = "22" }
                        }
                    }
                }
                if (relay == true) {
                    HStack() {
                        Text("Remote IP").frame(width: 100, alignment: .leading)
                        Spacer()
                        TextField("", text: $remoteIp).frame(width: 200).onExitCommand(perform: { remoteIp = "" })
                    }
                }
                HStack() {
                    Text("Remote Port").frame(width: 100, alignment: .leading)
                    Spacer()
                    TextField("", text: $remotePortStr).multilineTextAlignment(.trailing).frame(width: 200)
                }
            }.padding()
            HStack() {
                Button("OK") {
                    guard let mc = mc, let devicesView = devicesView else { return }
                    devicesView.showAddMapModal = false
                    devicesView.showAddRelayMapModal = false
                    mc.addPortMap(name:name, nodeid:nodeid, usage:usage, localPort:Int(localPortStr) ?? 0, remoteIp: (relay == true) ? remoteIp : nil ,remotePort:Int(remotePortStr) ?? 0)
                }.disabled(
                    !(((Int(localPortStr) ?? -1) >= 0) && ((Int(localPortStr) ?? -1) <= 65535) && ((Int(remotePortStr) ?? -1) > 0) && ((Int(remotePortStr) ?? -1) <= 65535) && (meshid != "") && (nodeid != "") && ((relay == false) || (remoteIp != "")))
                )
                Button("Cancel") {
                    guard let devicesView = devicesView else { return }
                    devicesView.showAddMapModal = false
                    devicesView.showAddRelayMapModal = false
                }
            }.padding([.horizontal, .bottom])
        }.background(Color("MainBackground")).foregroundColor(Color("MainTextColor")).shadow(radius: 20)
    }
}

struct AddMapDialogView_Previews: PreviewProvider {
    static var previews: some View {
        AppMapDialogView(devicesView:nil, device:nil, relay:true)
    }
}
