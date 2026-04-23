import { ChatMessage, MessageRole } from '../models/ChatModels';

export function normalizeConversationPath(messages: ChatMessage[]): boolean {
  let changed: boolean = false;
  let previousId: string = '';
  let previousUserId: string = '';

  for (let i = 0; i < messages.length; i++) {
    const message: ChatMessage = messages[i];
    if (message.role === MessageRole.ASSISTANT && message.branchParentId.length === 0 && previousUserId.length > 0) {
      message.branchParentId = previousUserId;
      message.branchIndex = 1;
      message.branchActive = true;
      changed = true;
    }
    if (message.pathParentId.length === 0 && previousId.length > 0) {
      if (message.role === MessageRole.ASSISTANT && message.branchParentId.length > 0) {
        message.pathParentId = message.branchParentId;
      } else {
        message.pathParentId = previousId;
      }
      changed = true;
    }
    if (message.role === MessageRole.USER) {
      previousUserId = message.id;
    }
    previousId = message.id;
  }

  return changed;
}

export function getActivePathMessages(messages: ChatMessage[]): ChatMessage[] {
  if (!hasPathMetadata(messages)) {
    const legacyActive: ChatMessage[] = [];
    for (let i = 0; i < messages.length; i++) {
      const message: ChatMessage = messages[i];
      if (isInactiveAssistantBranch(message)) {
        continue;
      }
      legacyActive.push(message);
    }
    return legacyActive;
  }

  const active: ChatMessage[] = [];
  let parentId: string = '';
  while (true) {
    const child: ChatMessage | null = findActivePathChild(messages, parentId);
    if (child === null) {
      break;
    }
    active.push(child);
    parentId = child.id;
  }
  return active;
}

function findActivePathChild(messages: ChatMessage[], parentId: string): ChatMessage | null {
  for (let i = 0; i < messages.length; i++) {
    const message: ChatMessage = messages[i];
    if (message.pathParentId !== parentId) {
      continue;
    }
    if (isInactiveAssistantBranch(message)) {
      continue;
    }
    return message;
  }
  return null;
}

function hasPathMetadata(messages: ChatMessage[]): boolean {
  for (let i = 0; i < messages.length; i++) {
    if (messages[i].pathParentId.length > 0) {
      return true;
    }
  }
  return false;
}

function isInactiveAssistantBranch(message: ChatMessage): boolean {
  return message.role === MessageRole.ASSISTANT && message.branchParentId.length > 0 && !message.branchActive;
}
