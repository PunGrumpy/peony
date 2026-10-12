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

// Pulse ships as Ivanti's wordmark, so its logo runs wide.
export const vpns = [
  { id: "fortigate", name: "FortiGate" },
  { id: "anyconnect", name: "AnyConnect" },
  { id: "globalprotect", name: "GlobalProtect" },
  { id: "pulse", name: "Pulse", wide: true },
  { id: "f5", name: "F5" },
  { id: "wireguard", name: "WireGuard" },
  { id: "netbird", name: "NetBird" },
] as const;

export const clients = [
  { command: "brew install openfortivpn", vpn: "FortiGate SSL-VPN" },
  {
    command: "brew install openconnect",
    vpn: "AnyConnect, GlobalProtect, Pulse, F5, Array",
  },
  { command: "brew install wireguard-tools", vpn: "WireGuard" },
] as const;

export const netbird = "https://docs.netbird.io/how-to/installation";
