import {BeamMutationObserver} from "../../../Helpers/Utils/Web/BeamTypes"

export class WebFactory  {
  MutationObserver: BeamMutationObserver
  createMutationObserver(fn) {
    return new MutationObserver(fn) as unknown as BeamMutationObserver
  }
}
