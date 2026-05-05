//
//  CertificateView.swift
//  MeshCentral Router
//
//  Created by Default on 12/18/20.
//

import SwiftUI
import Combine

extension DevicesView {
    enum Tab: Hashable {
        case devices
        case mappings
    }
}

private struct DeviceListSection: Identifiable {
    let id: String
    let name: String
    let devices: [Device]
}

struct DevicesView: View {
    @State var selectedTab: Tab = .devices
    @State var deviceFilter:String = ""
    @State var showSettingsModal: Bool = false
    @State var showAddMapModal: Bool = false
    @State var showAddRelayMapModal: Bool = false
    @State var showSshUserModal: Bool = false
    @State var showHelpModal: Bool = false
    @ObservedObject var xmc:MeshCentralServerChanger = meshCentralServerChanger
    
    init() { }
    
    func openURL(url:String) {
        NSWorkspace.shared.open(URL(string: url)!)
    }
    
    func openSSH(port:Int) {
        /*
        let task = Process()
        task.launchPath = "/usr/bin/ssh"
        //task.arguments = ["-p", "\(port)", "127.0.0.1"]
        task.arguments = ["-p", "22", "192.168.2.113"]
        task.launch()
        */
        //UIApplication
    }
    
    private func checkFilter(device:Device, filter:String) -> Bool {
        if (globalShowOnlyOnlineDevices && ((device.conn & 1) == 0)) { return false }
        if (filter == "") { return true }
        return device.name.range(of: filter, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func buildDeviceSections(mc:MeshCentralServer) -> [DeviceListSection] {
        let filter = deviceFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        var devicesByGroup:[String:[Device]] = [:]
        devicesByGroup.reserveCapacity(mc.deviceGroups.count)

        for dev:Device in mc.devices {
            if (checkFilter(device:dev, filter:filter)) {
                devicesByGroup[dev.meshid, default: []].append(dev)
            }
        }

        var sections:[DeviceListSection] = []
        sections.reserveCapacity(mc.deviceGroups.count)
        for grp:DeviceGroup in mc.deviceGroups {
            if let devices = devicesByGroup[grp.id], devices.count > 0 {
                sections.append(DeviceListSection(id: grp.id, name: grp.name, devices: devices))
            }
        }
        return sections
    }
    
    func getStateString(device:Device) -> String {
        var r:[String] = [String]()
        if ((device.conn & 1) != 0) { r.append("Agent") }
        if ((device.conn & 2) != 0) { r.append("CIRA") }
        if ((device.conn & 4) != 0) { r.append("AMT") }
        if ((device.conn & 8) != 0) { r.append("Relay") }
        if ((device.conn & 16) != 0) { r.append("MQTT") }
        return r.joined(separator: ", ")
    }

    private func deviceToolbar() -> some View {
        HStack {
            TextField("Filter", text: $deviceFilter)
                .frame(width: 220)
                .foregroundColor(Color("MainTextColor"))
                .onExitCommand(perform: {
                    deviceFilter = ""
                })
            Spacer()
            Button("Settings...", action: { showSettingsModal = true }).sheet(isPresented: $showSettingsModal) {
                SettingsDialogView(devicesView:self)
            }
            .buttonStyle(BorderedButtonStyle())
        }.padding(.horizontal, 10).padding(.top, 4).frame(width: 494, height: 32)
    }

    @ViewBuilder
    private func devicesContent(mc:MeshCentralServer) -> some View {
        let sections = buildDeviceSections(mc: mc)

        if (sections.count == 0) {
            Text(deviceFilter.trimmingCharacters(in: .whitespacesAndNewlines) == "" ? "No devices" : "No filtered devices")
                .foregroundColor(Color("MainTextColor"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List() {
                ForEach(sections) { section in
                    Section(header: Text(section.name).foregroundColor(Color("MainTextColor"))) {
                        ForEach(section.devices, id: \.id) { device in
                            deviceRow(device:device)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func deviceRow(device:Device) -> some View {
        HStack() {
            Image("Device\(device.icon)")
                .opacity(((device.conn & 1) != 0) ? 1 : 0.3)
                .saturation(((device.conn & 1) != 0) ? 1 : 0)
            VStack(alignment: .leading) {
                Text(device.name)
                Text(getStateString(device:device))
            }.frame(maxWidth: .infinity, alignment: .leading)
            if ((device.conn & 1) != 0) {
                Button("Add map...") { [weak device] in
                    guard let device = device else { return }
                    globalSelectedDevice = device
                    showAddMapModal = true
                }
            }
        }.padding(.horizontal, 5).background(Color("MainItemColor")).cornerRadius(4).contextMenu() {
            if ((device.conn & 1) != 0) {
                Button("Add map...") { [weak device] in
                    guard let device = device else { return }
                    globalSelectedDevice = device
                    showAddMapModal = true
                }
                Button("Add relay map...") { [weak device] in
                    guard let device = device else { return }
                    globalSelectedDevice = device
                    showAddRelayMapModal = true
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    VStack(spacing: 0) {
                        deviceToolbar()
                        if let mc = mc, mc.devices.count > 0 {
                            devicesContent(mc: mc)
                        } else {
                            Text("No devices").foregroundColor(Color("MainTextColor")).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }.tabItem {
                        Text("Devices")
                    }.tag(Tab.devices)
                    VStack(spacing: 0) {
                        if let mc = mc, mc.portMaps.count > 0 {
                            List() {
                                ForEach(mc.portMaps, id: \.id) { map in
                                    HStack() {
                                        Image("Device\(map.device.icon)")
                                        VStack(alignment: .leading) {
                                            Text((map.name != "") ? "\(map.device.name): \(map.name)" : "\(map.device.name)")
                                            Text(map.getStateStr())
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        if (map.usage == "HTTP") {
                                            Button("HTTP") { [weak map] in
                                                guard let map = map else { return }
                                                openURL(url:"http://127.0.0.1:\(map.localPort)")
                                            }
                                        } else if (map.usage == "HTTPS") {
                                            Button("HTTPS") { [weak map] in
                                                guard let map = map else { return }
                                                openURL(url:"https://127.0.0.1:\(map.localPort)")
                                            }
                                        } else if (map.usage == "SSH") {
                                            Button("SSH") {
                                                showSshUserModal = true
                                            }.sheet(isPresented: $showSshUserModal) {
                                                SshUserDialogView(devicesView:self, localPort:map.localPort)
                                            }
                                        }
                                        Button("Delete") { [weak map] in
                                            guard let map = map else { return }
                                            mc.removePortMap(map: map)
                                        }
                                    }.padding(.horizontal, 5).background(Color("MainItemColor")).cornerRadius(4).contextMenu() {
                                        if (map.usage == "HTTP") {
                                            Button("HTTP") { [weak map] in
                                                guard let map = map else { return }
                                                openURL(url:"http://127.0.0.1:\(map.localPort)")
                                            }
                                        } else if (map.usage == "HTTPS") {
                                            Button("HTTPS") { [weak map] in
                                                guard let map = map else { return }
                                                openURL(url:"https://127.0.0.1:\(map.localPort)")
                                            }
                                        } else if (map.usage == "SSH") {
                                            Button("SSH") {
                                                showSshUserModal = true
                                            }.sheet(isPresented: $showSshUserModal) {
                                                SshUserDialogView(devicesView:self, localPort:map.localPort)
                                            }
                                        }
                                        Button("Delete") { [weak map] in
                                            guard let map = map else { return }
                                            mc.removePortMap(map: map)
                                        }
                                    }
                                }
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Text("No mappings").foregroundColor(Color("MainTextColor")).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        HStack {
                            Button("Help", action: { showHelpModal = true }).sheet(
                                isPresented: $showHelpModal) {
                                HelpDialogView(devicesView:self)
                            }
                            Spacer()
                            Button("Add Relay Map...", action: { globalSelectedDevice = nil; showAddRelayMapModal = true })
                            Button("Add Map...", action: { globalSelectedDevice = nil; showAddMapModal = true })
                        }.padding(.horizontal, 10).padding(.top, 4).frame(width: 494, height: 26)
                    }.tabItem {
                        Text("Mappings")
                    }.tag(Tab.mappings)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, -10)
            }.background(Color("MainBackground")).foregroundColor(.black)
            .sheet(isPresented: $showAddRelayMapModal) {
                AppMapDialogView(devicesView:self, device: globalSelectedDevice, relay: true)
            }
            HStack {
                Spacer()
                Button("Logout", action: logout)
                    .buttonStyle(BorderedButtonStyle())
                    .foregroundColor(.white)
                    .padding()
            }.background(Image("BottomBanner")).frame(width: 494, height: 41)
            .sheet(isPresented: $showAddMapModal) {
                AppMapDialogView(devicesView:self, device: globalSelectedDevice, relay: false)
            }
        }
        .frame(width: 494)
        .frame(minHeight: 360, maxHeight: .infinity)
        .background(Color("MainBackground"))
        .foregroundColor(Color("MainTextColor"))
        .onAppear(perform: { devicesScreenDisplayed(devicesView:self) })
    }
}

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
    }
}
