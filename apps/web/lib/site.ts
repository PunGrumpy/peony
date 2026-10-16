import app from "../../macos/package.json";

const repo = "https://github.com/PunGrumpy/peony";
const tag = encodeURIComponent(`@peony/macos@${app.version}`);

export const site = {
  author: {
    handle: "@pungrumpy",
    name: "Noppakorn Kaewsalabnil",
    url: "https://www.pungrumpy.com",
  },
  brew: "brew install --cask pungrumpy/tap/peony",
  description:
    "A menu bar app that switches between your VPNs and keeps only one on, so their routes and DNS never fight. Then it checks the hosts you care about.",
  download: `${repo}/releases/download/${tag}/Peony-${app.version}.dmg`,
  license: `${repo}/blob/main/LICENSE`,
  name: "Peony",
  releases: `${repo}/releases`,
  repo,
  tagline: "One VPN at a time, from the menu bar",
  version: app.version,
};

// Each logo is its vendor's wordmark. Width is set per logo so a wide
// wordmark and a compact one carry about the same weight.
export const vpns = [
  { id: "fortigate", name: "FortiGate", width: 122 },
  { id: "anyconnect", name: "AnyConnect", width: 57 },
  { id: "globalprotect", name: "GlobalProtect", width: 96 },
  { id: "pulse", name: "Pulse", width: 69 },
  { id: "f5", name: "F5", width: 32 },
  { id: "openvpn", name: "OpenVPN", width: 97 },
  { id: "wireguard", name: "WireGuard", width: 103 },
  { id: "netbird", name: "NetBird", width: 100 },
  { id: "tailscale", name: "Tailscale", width: 97 },
] as const;

export const clients = [
  { command: "brew install openfortivpn", vpn: "FortiGate SSL-VPN" },
  {
    command: "brew install openconnect",
    vpn: "AnyConnect, GlobalProtect, Pulse, F5, Array",
  },
  { command: "brew install openvpn", vpn: "OpenVPN" },
  { command: "brew install wireguard-tools", vpn: "WireGuard" },
  { command: "brew install --cask tailscale-app", vpn: "Tailscale" },
] as const;

export const netbird = "https://docs.netbird.io/how-to/installation";
