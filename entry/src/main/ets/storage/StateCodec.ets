import { CabinState, Device, Rule, Sample, EventLog } from '../model/Models';
import { CabinEngine } from '../engine/CabinEngine';

export class DecodeResult {
  state: CabinState = CabinEngine.initial();
  recovered: boolean = false;
  message: string = '';
}
export class StateCodec {
  static encode(s: CabinState): string { return JSON.stringify(s); }
  static decode(text: string): DecodeResult {
    const result = new DecodeResult();
    if (text === '') { result.message = '首次启动，已载入初始配置'; return result; }
    try {
      const s = JSON.parse(text) as CabinState;
      if (!s || s.schemaVersion !== 1 || !s.environment || !Array.isArray(s.devices) || !Array.isArray(s.rules) ||
        !Array.isArray(s.logs) || !Array.isArray(s.samples) || typeof s.automation !== 'boolean' ||
        !Number.isInteger(s.tick) || s.tick < 0 || !Number.isInteger(s.sequence) || s.sequence < 0 ||
        typeof s.savedAt !== 'string') { throw new Error('存档结构无效'); }
      const e = s.environment;
      if (![e.temperature, e.humidity, e.light].every((v: number) => typeof v === 'number' && Number.isFinite(v)) ||
        e.temperature < -10 || e.temperature > 60 || e.humidity < 0 || e.humidity > 100 || e.light < 0 || e.light > 2000) {
        throw new Error('传感器数据无效');
      }
      if (s.devices.length !== 3 || ['fan', 'pump', 'lamp'].some((id: string) => s.devices.filter((d: Device) => d && d.id === id).length !== 1) ||
        s.devices.some((d: Device) => typeof d.on !== 'boolean' || typeof d.online !== 'boolean' || typeof d.manual !== 'boolean' ||
          typeof d.name !== 'string' || typeof d.reason !== 'string' || (!d.online && d.on))) { throw new Error('设备数据无效'); }
      if (s.rules.length > 20 || s.rules.some((r: Rule) => CabinEngine.validateRule(r) !== '' || typeof r.id !== 'string' || r.id.length === 0) ||
        s.rules.some((r: Rule, i: number) => s.rules.findIndex((v: Rule) => v.id === r.id) !== i)) { throw new Error('规则数据无效'); }
      if (s.logs.length > 100 || s.logs.some((l: EventLog) => !l || !Number.isInteger(l.id) || l.id < 1 || l.id > s.sequence ||
        typeof l.time !== 'string' || typeof l.kind !== 'string' || typeof l.message !== 'string')) { throw new Error('日志数据无效'); }
      if (s.samples.length > 12 || s.samples.some((v: Sample) => !v || !Number.isInteger(v.tick) || v.tick < 1 || v.tick > s.tick ||
        !Number.isFinite(v.temperature) || !Number.isFinite(v.humidity) || !Number.isFinite(v.light))) { throw new Error('采样数据无效'); }
      result.state = s; result.recovered = true; result.message = '已恢复上次保存的数据';
    } catch (_) { result.message = '存档损坏或版本不兼容，已使用初始配置；原存档保留至下次主动保存'; }
    return result;
  }
}
