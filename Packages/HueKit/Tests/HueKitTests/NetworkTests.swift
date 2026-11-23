import Testing
@testable import HueKit

@Test func subnetMaths() {
    #expect(HueNetwork.isInSubnet(ip: "192.168.0.10", address: "192.168.0.42", netmask: "255.255.255.0"))
    #expect(!HueNetwork.isInSubnet(ip: "192.168.0.10", address: "192.168.1.42", netmask: "255.255.255.0"))
    #expect(HueNetwork.isInSubnet(ip: "192.168.0.10", address: "192.168.1.42", netmask: "255.255.0.0"))
    #expect(!HueNetwork.isInSubnet(ip: "10.0.0.1", address: "192.168.1.42", netmask: "255.255.0.0"))
    for bad in ["", "999.1.1.1", "abc", "1.2.3"] {
        #expect(!HueNetwork.isInSubnet(ip: bad, address: "192.168.0.1", netmask: "255.255.255.0"))
        #expect(!HueNetwork.isInSubnet(ip: "192.168.0.1", address: "192.168.0.1", netmask: bad))
    }
    #expect(!HueNetwork.isInSubnet(ip: "8.8.8.8", address: "192.168.0.1", netmask: "0.0.0.0"))
}
