import { BeamEmbedContentSize } from "@beam/native-beamtypes"

export interface EmbedNodeUI {
  sendContentSize(sizing: BeamEmbedContentSize): void
}
