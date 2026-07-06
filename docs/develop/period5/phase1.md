# Phase 1: Render Pass / Attachment Model

Phase 1 expands render-pass attachment descriptors while keeping backend
lowering explicit about unsupported combinations.

## First Slice

- Define color, depth, and stencil attachment shapes.
- Keep load actions, store actions, clear values, and resolve targets portable.
- Represent multiple color attachments in the public descriptor model.
- Add transient attachment metadata as a capability-gated hint.
- Keep unsupported native lowering behind typed runtime errors.

## Current Limits

- Existing runtime lowering supports one color attachment.
- Stencil and transient attachment lowering are validation/API shape first.
