import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CabinEngine } from '../engine/CabinEngine';
import { CabinState } from '../model/Models';
import { StateCodec } from './StateCodec';

export class CabinStore {
  static engine: CabinEngine = new CabinEngine();
  static status: string = '尚未加载';
  static ready: boolean = false;
  private static prefs: preferences.Preferences | undefined = undefined;
  private static tail: Promise<void> = Promise.resolve();

  static async load(context: common.UIAbilityContext): Promise<void> {
    if (CabinStore.ready) { return; }
    try {
      CabinStore.prefs = await preferences.getPreferences(context, { name: 'qinghe_state' });
      const raw = await CabinStore.prefs.get('snapshot', '');
      const result = StateCodec.decode(typeof raw === 'string' ? raw : 'INVALID');
      CabinStore.engine = new CabinEngine(result.state);
      CabinStore.status = result.message;
      CabinStore.ready = true;
    } catch (_) { CabinStore.status = '读取失败，请返回重试；暂不允许覆盖存档'; }
  }
  static save(): Promise<boolean> {
    // 在入队前捕获不可变快照，串行写入，避免旧写入晚到覆盖新状态。
    if (!CabinStore.ready || !CabinStore.prefs) { return Promise.resolve(false); }
    const now = new Date().toISOString();
    const copy = JSON.parse(StateCodec.encode(CabinStore.engine.state)) as CabinState;
    copy.savedAt = now;
    const raw = StateCodec.encode(copy);
    const operation: Promise<void> = CabinStore.tail.then(async () => {
      if (!CabinStore.prefs) { throw new Error('存储未初始化'); }
      await CabinStore.prefs.put('snapshot', raw);
      await CabinStore.prefs.flush();
      CabinStore.engine.state.savedAt = now;
      CabinStore.status = '已保存 ' + new Date(now).toLocaleTimeString();
    });
    CabinStore.tail = operation.catch(() => {});
    return operation.then(() => true).catch(() => { CabinStore.status = '保存失败，请重试'; return false; });
  }
}
