import Foundation

extension HueClient {
    func configureHueHTTPS(bridgeId: String) {
        guard let d = HueTrustDelegate(bridgeId: bridgeId) else {
            self.bridgeStatus = "Delegate Failed"
            return
        }

        self.hueDelegate = d

        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [:]
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 6

        // Sessions retain their delegate until invalidated (no-op on .shared)
        hueSession.finishTasksAndInvalidate()
        self.hueSession = URLSession(configuration: config, delegate: d, delegateQueue: nil)
    }
    
    public func unpair() {
        for key in ["hueBridgeIP", "hueUsername", "hueBridgeID"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        hueSession.finishTasksAndInvalidate()
        hueSession = URLSession.shared
        hueDelegate = nil
        
        bridgeIP = ""
        bridgeID = ""
        username = ""
        rooms = []
        lastRefresh = nil
        bridgeStatus = ""
        fetchStatus = ""
        connection = .checking
        bridgeState = .noBridge
    }
    
    public func discoverBridge() async {
        self.bridgeStatus = "Discovering Hue Bridge"
        
        let url = URL(string: "https://discovery.meethue.com")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                self.bridgeStatus = "Discovery failed (bad request)"
                return
            }
                
            let items = try JSONDecoder().decode([DiscoveryItem].self, from: data)
            guard let first = items.first else {
                self.bridgeStatus = "No bridge found"
                return
            }
            
            configureHueHTTPS(bridgeId: first.id)
            
            self.bridgeState = .bridgeFound
            self.bridgeIP = first.internalipaddress
            self.bridgeID = first.id
            self.bridgeStatus = "Press the button on bridge to pair"
        } catch {
            self.bridgeStatus = "Discovery failed"
        }
    }
    
    public func setBridge(ip: String) async {
        func isValidIPv4Regex(_ ip: String) -> Bool {
            let pattern =
            #"^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$"#
            return ip.range(of: pattern, options: .regularExpression) != nil
        }
        
        guard isValidIPv4Regex(ip) else {
            self.bridgeStatus = "Invalid IP address entered"
            return
        }
        
        self.bridgeStatus = "Connecting to Hue Bridge"
        
        let url = URL(string: "http://\(ip)/api/0/config")!
        
        // Should timeout quickly if wrong ip entered
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        config.waitsForConnectivity = false
        config.connectionProxyDictionary = [:]
        
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                self.bridgeStatus = "Failed to connect with Hue Bridge"
                return
            }
                
            let configBridge: ConfigBridge = try JSONDecoder().decode(ConfigBridge.self, from: data)

            configureHueHTTPS(bridgeId: configBridge.bridgeid)
            
            self.bridgeState = .bridgeFound
            self.bridgeIP = ip
            self.bridgeID = configBridge.bridgeid
            self.bridgeStatus = "Press the button on bridge to pair"
        } catch {
            self.bridgeStatus = "Could not find Hue Bridge"
        }
    }
    
    public func pairBridge() async {
        guard !bridgeIP.isEmpty else {
            self.bridgeState = .noBridge
            return
        }

        isPairing = true
        defer { isPairing = false }

        // The link button stays active for 30s after being pressed, so keep trying for that long
        let deadline = Date().addingTimeInterval(30)
        bridgeStatus = "Press the button on the bridge to pair."
        while bridgeState == .bridgeFound, Date() < deadline {
            if await attemptPair() { return }
            try? await Task.sleep(for: .seconds(2))
        }

        if bridgeState == .bridgeFound {
            bridgeStatus = "Pairing timed out."
        }
    }

    // Returns true when finished (paired or failed), false when the link button hasn't been pressed yet
    func attemptPair() async -> Bool {
        let url = URL(string: "https://\(self.bridgeIP)/api")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(
                PairRequest(
                    devicetype: "huemenubar",
                    generateclientkey: true
                )
            )
            
            let (data, response) = try await hueSession.data(for: request)
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                self.bridgeStatus = "Pairing failed"
                Self.log.error("Pairing response was not 2xx")
                return true
            }

            let items = try JSONDecoder().decode([PairingItem].self, from: data)
            guard let first = items.first else {
                self.bridgeStatus = "Pairing failed"
                Self.log.error("Pairing response was empty")
                return true
            }

            if let error = first.error {
                // 101: link button not pressed
                guard error.type == 101 else {
                    self.bridgeStatus = "Pairing failed: \(error.description)"
                    return true
                }
                return false
            }

            // Cancelled while the request was in flight
            guard bridgeState == .bridgeFound else { return true }

            if let success = first.success {
                self.username = success.username
                Self.log.info("Paired with bridge \(self.bridgeID)")
                self.connection = .checking
                self.bridgeState = .paired
                
                // Store State
                UserDefaults.standard.set(success.username, forKey: "hueUsername")
                UserDefaults.standard.set(self.bridgeID, forKey: "hueBridgeID")
                UserDefaults.standard.set(self.bridgeIP, forKey: "hueBridgeIP")
                
                await refresh()
            }
            return true
        }
        catch {
            self.bridgeStatus = "Pairing failed"
            Self.log.error("Pairing request failed: \(error)")
            return true
        }
    }
    
}
