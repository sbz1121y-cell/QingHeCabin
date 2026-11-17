import { CabinState, Device, DeviceKey, Environment, EventLog, Rule, Sample, SensorKey } from '../model/Models';

// 纯业务类不引用 ArkUI 和系统服务，时钟由调用方注入，便于 Mock 测试。
export class CabinEngine {
  state: CabinState;
  constructor(state: CabinState = CabinEngine.initial()) { this.state = state; }

  static initial(): CabinState {
    const s = new CabinState();
    s.devices = [new Device('fan', '通风扇'), new Device('pump', '灌溉泵'), new Device('lamp', '补光灯')];
    const hot = new Rule(); hot.id = 'hot'; hot.name = '高温通风'; hot.threshold = 30;
    const dry = new Rule(); dry.id = 'dry'; dry.name = '低湿灌溉'; dry.sensor = 'humidity';
    dry.compare = 'below'; dry.threshold = 40; dry.device = 'pump';
    const dark = new Rule(); dark.id = 'dark'; dark.name = '弱光补光'; dark.sensor = 'light';
    dark.compare = 'below'; dark.threshold = 300; dark.device = 'lamp';
    s.rules = [hot, dry, dark];
    return s;
  }
  static range(key: SensorKey): number[] {
    if (key === 'temperature') { return [-10, 60]; }
    if (key === 'humidity') { return [0, 100]; }
    return [0, 2000];
  }
  static value(e: Environment, key: SensorKey): number {
    if (key === 'temperature') { return e.temperature; }
    if (key === 'humidity') { return e.humidity; }
    return e.light;
  }
  static validateRule(r: Rule): string {
    if (!r || typeof r.name !== 'string' || r.name.trim().length < 1 || r.name.trim().length > 20) {
      return '规则名称应为 1～20 个字符';
    }
    if (!['temperature', 'humidity', 'light'].includes(r.sensor) || !['fan', 'pump', 'lamp'].includes(r.device) ||
      !['above', 'below'].includes(r.compare)) { return '规则字段无效'; }
    const range = CabinEngine.range(r.sensor);
    if (typeof r.threshold !== 'number' || !Number.isFinite(r.threshold) || r.threshold < range[0] || r.threshold > range[1]) {
      return '阈值超出传感器范围';
    }
    if (!Number.isInteger(r.priority) || r.priority < 1 || r.priority > 99) { return '优先级须为 1～99 的整数'; }
    if (typeof r.action !== 'boolean' || typeof r.enabled !== 'boolean') { return '规则开关无效'; }
    return '';
  }
  log(kind: string, message: string, now: string): void {
    const e = new EventLog(); e.id = ++this.state.sequence; e.time = now; e.kind = kind; e.message = message;
    this.state.logs = [e].concat(this.state.logs).slice(0, 100);
  }
  evaluate(now: string): void {
    if (!this.state.automation) { return; }
    // 优先级大者获胜；同优先级按稳定 id 升序。无命中时自动设备关闭。
    const ordered = this.state.rules.filter((r: Rule) => r.enabled).sort((a: Rule, b: Rule) => {
      if (a.priority !== b.priority) { return b.priority - a.priority; }
      return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    });
    this.state.devices.forEach((d: Device) => {
      if (!d.online || d.manual) { return; }
      const hits = ordered.filter((r: Rule) => {
        const v = CabinEngine.value(this.state.environment, r.sensor);
        return r.device === d.id && (r.compare === 'above' ? v > r.threshold : v < r.threshold);
      });
      const on = hits.length > 0 ? hits[0].action : false;
      const reason = hits.length > 0 ? '规则：' + hits[0].name : '无规则命中，安全关闭';
      if (d.on !== on) { this.log('联动', d.name + (on ? '开启' : '关闭') + ' · ' + reason, now); }
      d.on = on; d.reason = reason;
    });
  }
  setEnvironment(key: SensorKey, value: number, now: string): string {
    const range = CabinEngine.range(key);
    if (!Number.isFinite(value) || value < range[0] || value > range[1]) { return '环境数值超出范围'; }
    if (key === 'temperature') { this.state.environment.temperature = value; }
    else if (key === 'humidity') { this.state.environment.humidity = value; }
    else { this.state.environment.light = value; }
    this.evaluate(now); return '';
  }
  saveRule(rule: Rule, now: string): string {
    const error = CabinEngine.validateRule(rule); if (error) { return error; }
    const index = this.state.rules.findIndex((r: Rule) => r.id === rule.id);
    if (index < 0 && this.state.rules.length >= 20) { return '最多保存 20 条规则'; }
    const copy = JSON.parse(JSON.stringify(rule)) as Rule;
    copy.name = copy.name.trim();
    if (index < 0) { copy.id = 'r' + (++this.state.sequence); this.state.rules.push(copy); }
    else { this.state.rules[index] = copy; }
    this.log('规则', '保存规则：' + copy.name, now); this.evaluate(now); return '';
  }
  removeRule(id: string, now: string): void {
    this.state.rules = this.state.rules.filter((r: Rule) => r.id !== id);
    this.log('规则', '删除规则：' + id, now); this.evaluate(now);
  }
  toggleRule(id: string, now: string): void {
    const r = this.state.rules.find((v: Rule) => v.id === id);
    if (r) { r.enabled = !r.enabled; this.log('规则', (r.enabled ? '启用' : '停用') + r.name, now); this.evaluate(now); }
  }
  control(id: DeviceKey, on: boolean, now: string): string {
    const d = this.state.devices.find((v: Device) => v.id === id);
    if (!d || !d.online) { return '设备离线，无法控制'; }
    d.on = on; d.manual = true; d.reason = '手动接管，自动规则暂停控制此设备';
    this.log('手动', d.name + (on ? '开启' : '关闭'), now); return '';
  }
  release(id: DeviceKey, now: string): void {
    const d = this.state.devices.find((v: Device) => v.id === id);
    if (d) { d.manual = false; this.log('手动', d.name + '交还自动控制', now); this.evaluate(now); }
  }
  setOnline(id: DeviceKey, online: boolean, now: string): void {
    const d = this.state.devices.find((v: Device) => v.id === id);
    if (d) {
      d.online = online;
      if (!online) { d.on = false; d.manual = false; d.reason = '设备离线'; }
      this.log('设备', d.name + (online ? '恢复在线' : '模拟离线'), now); this.evaluate(now);
    }
  }
  setAutomation(enabled: boolean, now: string): void {
    this.state.automation = enabled;
    this.log('系统', enabled ? '自动联动已启用' : '自动联动已暂停，设备保留当前状态', now);
    this.evaluate(now);
  }
  step(now: string): void {
    const e = this.state.environment;
    const running = (id: DeviceKey): boolean => this.state.devices.some((d: Device) => d.id === id && d.online && d.on);
    e.temperature = Math.round(Math.max(-10, Math.min(60, e.temperature + (running('fan') ? -1.2 : 0.4))) * 10) / 10;
    e.humidity = Math.round(Math.max(0, Math.min(100, e.humidity + (running('pump') ? 3 : -0.8))) * 10) / 10;
    e.light = Math.round(Math.max(0, Math.min(2000, e.light + (running('lamp') ? 60 : -20))));
    this.state.tick++;
    this.evaluate(now);
    const s = new Sample(); s.tick = this.state.tick; s.temperature = e.temperature; s.humidity = e.humidity; s.light = e.light;
    this.state.samples = this.state.samples.concat([s]).slice(-12);
  }
}
