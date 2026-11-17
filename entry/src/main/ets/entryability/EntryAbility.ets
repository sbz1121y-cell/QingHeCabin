import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { CabinStore } from '../storage/CabinStore';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    stage.loadContent('pages/Index');
  }
  onBackground(): void {
    if (CabinStore.ready) { CabinStore.save(); }
  }
}
