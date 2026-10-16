import { spawn } from 'node:child_process';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

export default function (pi: ExtensionAPI) {
  // Use the desktop notification service instead of writing OSC bytes to stdout:
  // stdout is the JSONL protocol channel for Pi's RPC clients (including pi.nvim).
  pi.on('agent_settled', async (_event, ctx) => {
    if (ctx.mode !== 'tui' || !process.env.WAYLAND_DISPLAY) return;
    const child = spawn('notify-send', ['Pi', 'Ready for input'], { stdio: 'ignore' });
    child.on('error', () => {}); // notify-send is optional; never disrupt a coding session.
  });
}
