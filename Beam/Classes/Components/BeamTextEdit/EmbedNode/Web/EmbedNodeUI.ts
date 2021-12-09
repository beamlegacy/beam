import { BeamEmbedContentSize } from "../../../../Helpers/Utils/Web/BeamTypes"

export interface EmbedNodeUI {
  sendContentSize(sizing: BeamEmbedContentSize): void
}
