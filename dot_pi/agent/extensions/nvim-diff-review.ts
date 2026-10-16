/**
 * Route Pi `edit`/`write` tool calls through pi.nvim's pre-apply diff review.
 * In Pi's own terminal UI, the ordinary Accept/Reject selector is used.
 * Shell commands are deliberately not intercepted; instructions ask Pi to use
 * edit/write for source changes and reserve bash for inspection and checks.
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

const approved = new Set<string>();

type ReviewNote = {
  path: string;
  side: 'current' | 'proposed';
  lineStart: number;
  lineEnd: number;
  lines: string[];
  note: string;
};

function notesText(notes?: ReviewNote[]): string {
  if (!notes?.length) return '';
  return '\n\nReview notes:\n' + notes.map((note) => {
    const range = note.lineStart === note.lineEnd ? `${note.lineStart}` : `${note.lineStart}-${note.lineEnd}`;
    return `- ${note.side}:${range} ${JSON.stringify(note.lines)}\n  ${note.note}`;
  }).join('\n');
}

export default function (pi: ExtensionAPI) {
  pi.on('tool_call', async (event, ctx) => {
    if (event.toolName !== 'edit' && event.toolName !== 'write') return undefined;
    const path = (event.input as { path?: string }).path;
    if (!path) return undefined;
    if (!ctx.hasUI) {
      return { block: true, reason: `[rejected] No UI available to review ${event.toolName}` };
    }

    const title = JSON.stringify({
      prompt: `${event.toolName}: ${path}`,
      toolName: event.toolName,
      toolInput: event.input,
    });
    const choice = await ctx.ui.select(title, ['Accept', 'Reject']);

    // Native Pi TUI: allow the built-in tool to apply an accepted edit.
    if (choice === 'Accept') return undefined;

    // pi.nvim shows and applies the reviewed diff itself.
    if (typeof choice === 'string' && choice.startsWith('{')) {
      let result: { result?: string; content?: string; notes?: ReviewNote[] };
      try {
        result = JSON.parse(choice);
      } catch {
        ctx.abort();
        return { block: true, reason: `[rejected] Could not parse review response for ${path}` };
      }

      if (result.result === 'Accepted' || result.result === 'AcceptModified') {
        approved.add(event.toolCallId);
        const changed = result.result === 'AcceptModified';
        const content = changed && result.content ? `\n\nCurrent content of ${path}:\n\n${result.content}` : '';
        return {
          block: true,
          reason: `[accepted] User ${changed ? 'approved a modified version of' : 'approved'} ${path}; the reviewed change was already applied.${notesText(result.notes)}${content}`,
        };
      }
      if (result.result === 'Rejected') {
        return { block: true, reason: `[rejected] User rejected ${path}; file unchanged.${notesText(result.notes)}` };
      }
    }

    ctx.abort();
    return { block: true, reason: `[rejected] User rejected ${path}; file unchanged.` };
  });

  // The tool was intentionally blocked after pi.nvim applied the reviewed file.
  pi.on('message_end', async (event) => {
    const message = event.message as { role?: string; toolCallId?: string; isError?: boolean };
    if (message.role === 'toolResult' && message.toolCallId && approved.delete(message.toolCallId)) {
      message.isError = false;
    }
  });
}
