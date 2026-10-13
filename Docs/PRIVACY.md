# Privacy

Zhen looks at your local network on your Mac. It tells no one what it finds.

- **No accounts, no analytics, no telemetry, no crash reporting.** The app makes no
  connection to any server.
- **What it sends** is the scan: probes to addresses on the network you choose (by
  default your Mac's own), and Bonjour, UPnP, NetBIOS and reverse-DNS queries on that
  network. Turn on "Deep-scan new devices" and it also connects to common ports on each
  device the first time it answers. A port scan of one device does the same for that
  device.
- **What it keeps** is history: devices, their names, addresses, hardware addresses and
  ports, and the events between scans, in `~/Library/Application Support/zhen/history.ndjson`. That file is
  shared with the `zhen` command line. It never leaves your Mac unless you export it
  (File › Export History…, or the Export button in Settings, which writes a JSON file
  where you choose).
- **Notifications** (optional, off until you turn them on) are local: Notification Centre
  on this Mac, naming the new device and its address.
- **Names you give devices**, and your settings, are kept in the app's preferences on
  this Mac.
- **Local Network permission** is macOS's prompt: Zhen asks for it to scan, and works
  less fully without it. It says so, with a link to the setting.
- **The privileged helper** is optional and off until you install it. It opens a packet
  capture device for the layer-2 sweep and SYN scans, and talks only to this app: it
  checks each caller's code signature and is built to refuse anything that is not Zhen.
  Settings removes it in one click.

To remove everything Zhen stored:
- remove the helper in Settings
- delete the history file
- delete `~/Library/Preferences/com.jctec.zhen.plist`
- delete the app
