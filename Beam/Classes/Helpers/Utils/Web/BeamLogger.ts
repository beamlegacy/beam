import { BeamLogCategory, BeamLogLevel, BeamWindow, MessageHandlers } from "./BeamTypes"
import { Native } from "./Native"

export class BeamLogger {
  native: Native<any>
  category: BeamLogCategory

  constructor(win: BeamWindow, category: BeamLogCategory) {
    const componentPrefix = `beam_logger`
    this.native = new Native(win, componentPrefix)
    this.category = category
  }

  log(...args: unknown[]): void {
    const formattedMessage = this.convertArgsToMessage(args)
    this.sendMessage(formattedMessage, BeamLogLevel.log)
  }

  logWarning(...args: unknown[]): void {
    const formattedMessage = this.convertArgsToMessage(args)
    this.sendMessage(formattedMessage, BeamLogLevel.warning)
  }

  logDebug(...args: unknown[]): void {
    const formattedMessage = this.convertArgsToMessage(args)
    this.sendMessage(formattedMessage, BeamLogLevel.debug)
  }

  logError(...args: unknown[]): void {
    const formattedMessage = this.convertArgsToMessage(args)
    this.sendMessage(formattedMessage, BeamLogLevel.error)
  }

  private sendMessage(message: string, level: BeamLogLevel): void {
    this.native.sendMessage("log", {
      message,
      level,
      category: this.category
    })
  }

  private convertArgsToMessage(args: Object): string {
    const messageArgs = Object.values(args).map((value) => {
      let str
      if (typeof value === "object") {
        try {
          str = JSON.stringify(value)
        } catch (error) {
          console.error(error)
        }
      }
      if (!str) {
        str = String(value)
      }
      return str
    })
    return messageArgs
      .map((v) => v.substring(0, 3000)) // Limit msg to 3000 chars
      .join(", ")
  }
}
