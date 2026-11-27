import Foundation

enum HueNetwork {
    static func ipv4(_ string: String) -> UInt32? {
        var addr = in_addr()
        return inet_pton(AF_INET, string, &addr) == 1 ? UInt32(bigEndian: addr.s_addr) : nil
    }
    
    static func isInSubnet(ip: UInt32, address: UInt32, netmask: UInt32) -> Bool {
        netmask != 0 && ip & netmask == address & netmask
    }
    
    static func isInSubnet(ip: String, address: String, netmask: String) -> Bool {
        guard let ip = ipv4(ip), let address = ipv4(address), let netmask = ipv4(netmask) else { return false }
        return isInSubnet(ip: ip, address: address, netmask: netmask)
    }
    
    // Whether any up, non-loopback IPv4 interface shares a subnet with the bridge. Another network that
    // happens to use the same subnet (say a second 192.168.0.x) counts as the bridge's network too.
    static func isOnNetwork(of bridgeIP: String) -> Bool {
        guard let ip = ipv4(bridgeIP) else { return false }
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return false }
        defer { freeifaddrs(list) }
        
        for entry in sequence(first: list, next: { $0?.pointee.ifa_next }).compactMap({ $0?.pointee }) {
            let up = Int32(entry.ifa_flags) & IFF_UP != 0 && Int32(entry.ifa_flags) & IFF_LOOPBACK == 0
            guard up, let a = entry.ifa_addr, let m = entry.ifa_netmask, a.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let address = a.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let mask = m.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            if isInSubnet(ip: ip, address: address, netmask: mask) { return true }
        }
        return false
    }
}
