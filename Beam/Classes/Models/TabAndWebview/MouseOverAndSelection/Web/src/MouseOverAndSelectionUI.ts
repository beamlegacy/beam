export interface MouseOverAndSelectionUI {
  sendLinkMouseOut(arg0: {})
  sendLinkMouseOver(message: { url: any; target: any })
  sendSelectionChange(message: { selection: string })
}
