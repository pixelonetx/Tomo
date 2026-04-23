import { common } from '@kit.AbilityKit';
import { ChatMessage, Conversation } from '../models/ChatModels';
import { ConversationRdbService } from './ConversationRdbService';

export class ConversationService {
  private rdbService: ConversationRdbService = new ConversationRdbService();

  async init(context: common.Context): Promise<void> {
    await this.rdbService.init(context);
  }

  async loadConversations(): Promise<Conversation[]> {
    return await this.rdbService.loadConversationsWithMessages();
  }

  async createConversation(conversation: Conversation): Promise<void> {
    await this.rdbService.insertConversation(conversation);
  }

  async renameConversation(id: string, title: string, updatedAt: number): Promise<void> {
    await this.rdbService.updateConversationTitle(id, title, updatedAt);
  }

  async deleteConversation(id: string): Promise<void> {
    await this.rdbService.deleteConversation(id);
  }

  async insertMessage(message: ChatMessage): Promise<void> {
    await this.rdbService.insertMessage(message);
  }

  async updateMessage(message: ChatMessage): Promise<void> {
    await this.rdbService.insertMessage(message);
  }

  async deleteMessage(id: string): Promise<void> {
    await this.rdbService.deleteMessage(id);
  }

  async deleteMessages(ids: string[]): Promise<void> {
    await this.rdbService.deleteMessages(ids);
  }

  async deleteAllConversations(): Promise<void> {
    await this.rdbService.deleteAllConversations();
  }
}
