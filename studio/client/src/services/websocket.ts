/**
 * studio/client/src/services/websocket.ts -- Real-time Terminal WebSocket Client
 */

type MessageHandler = (data: any) => void;

class TerminalWebSocket {
  private ws: WebSocket | null = null;
  private messageHandlers: Set<MessageHandler> = new Set();
  private isConnecting = false;
  private reconnectTimer: any = null;

  connect() {
    if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
      return;
    }

    this.isConnecting = true;
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;
    const wsUrl = `${protocol}//${host}/ws/terminal`;

    this.ws = new WebSocket(wsUrl);

    this.ws.onopen = () => {
      this.isConnecting = false;
      console.log('[WS] Connected to live terminal stream');
    };

    this.ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        for (const handler of this.messageHandlers) {
          handler(data);
        }
      } catch (err) {
        console.error('[WS] Parse error:', err);
      }
    };

    this.ws.onclose = () => {
      this.isConnecting = false;
      this.ws = null;
      console.log('[WS] Disconnected, attempting reconnect in 2s...');
      if (!this.reconnectTimer) {
        this.reconnectTimer = setTimeout(() => {
          this.reconnectTimer = null;
          this.connect();
        }, 2000);
      }
    };

    this.ws.onerror = (err) => {
      console.warn('[WS] Socket error:', err);
    };
  }

  subscribe(handler: MessageHandler) {
    this.messageHandlers.add(handler);
    return () => this.messageHandlers.delete(handler);
  }

  send(message: any) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      console.warn('[WS] Socket not open, message dropped:', message);
    }
  }

  evaluate(code: string, timeout = 10, wd?: string) {
    this.send({
      type: 'eval',
      id: `eval-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
      code,
      timeout,
      wd
    });
  }

  reset() {
    this.send({
      type: 'reset',
      id: `reset-${Date.now()}`
    });
  }

  getWorkspace() {
    this.send({
      type: 'workspace',
      id: `ws-${Date.now()}`
    });
  }
}

export const terminalWs = new TerminalWebSocket();
