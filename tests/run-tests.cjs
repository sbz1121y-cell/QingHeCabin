// 直接转译并加载实际 ArkTS 纯业务源码；不维护第二份业务实现。
const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const crypto = require('crypto');
const sdk = process.env.DEVECO_HOME || 'D:/huawei/DevEco Studio';
const ts = require(process.env.TYPESCRIPT_PATH || path.join(sdk, 'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
require.extensions['.ets'] = (module, filename) => {
  const source = fs.readFileSync(filename, 'utf8');
  const out = ts.transpileModule(source, {compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021}});
  module._compile(out.outputText, filename);
};
const base=path.resolve(__dirname,'../entry/src/main/ets');
const {CabinEngine}=require(base+'/engine/CabinEngine.ets');
const {Rule}=require(base+'/model/Models.ets');
const {StateCodec}=require(base+'/storage/StateCodec.ets');
const records=[];
const now='12:00:00 MOCK';
function test(category,name,input,expected,fn){
  try { const actual=fn(); records.push({category,name,input,expected,actual,status:'PASS'}); }
  catch(e){records.push({category,name,input,expected,actual:e.message,status:'FAIL'});}
}
function device(e,id='fan'){return e.state.devices.find(d=>d.id===id);}
test('正常','高温触发通风','temperature=36','风扇开启',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);assert.equal(device(e).on,true);return '风扇开启';});
test('边界','严格大于阈值','temperature=30, threshold=30','风扇关闭',()=>{const e=new CabinEngine();e.setEnvironment('temperature',30,now);assert.equal(device(e).on,false);return '风扇关闭';});
test('边界','严格小于阈值','humidity=40, threshold=40','灌溉泵关闭',()=>{const e=new CabinEngine();e.setEnvironment('humidity',40,now);assert.equal(device(e,'pump').on,false);return '灌溉泵关闭';});
test('正常','冲突规则优先级','36°C；priority=99 关闭 fan','关闭规则获胜',()=>{const e=new CabinEngine();const r=new Rule();r.name='高优先关闭';r.priority=99;r.action=false;e.saveRule(r,now);e.setEnvironment('temperature',36,now);assert.equal(device(e).on,false);assert.match(device(e).reason,/高优先关闭/);return '关闭规则获胜';});
test('边界','同优先级稳定排序','aaa关闭, hot开启, priority均10','aaa规则获胜',()=>{const e=new CabinEngine();const r=new Rule();r.id='aaa';r.name='aaa关闭';r.action=false;e.state.rules.push(r);e.setEnvironment('temperature',36,now);assert.equal(device(e).on,false);return 'aaa规则获胜';});
test('正常','手动接管及交还','自动开启→手动关闭→再计算→交还','接管期间保持关闭，交还后开启',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);e.control('fan',false,now);e.evaluate(now);assert.equal(device(e).on,false);e.release('fan',now);assert.equal(device(e).on,true);return '接管期间保持关闭，交还后开启';});
test('异常','离线控制拦截','fan离线→手动开启','返回错误且设备关闭',()=>{const e=new CabinEngine();e.setOnline('fan',false,now);assert.ok(e.control('fan',true,now));e.setEnvironment('temperature',36,now);assert.equal(device(e).on,false);return '返回错误且设备关闭';});
test('正常','在线恢复重新联动','36°C；离线→在线','风扇重新开启',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);e.setOnline('fan',false,now);e.setOnline('fan',true,now);assert.equal(device(e).on,true);return '风扇重新开启';});
test('正常','暂停自动联动','关闭自动→temperature=36','状态保留，开启自动后联动',()=>{const e=new CabinEngine();e.setAutomation(false,now);e.setEnvironment('temperature',36,now);assert.equal(device(e).on,false);e.setAutomation(true,now);assert.equal(device(e).on,true);return '状态保留，开启自动后联动';});
test('正常','无命中安全关闭','temperature=36→26','风扇先开后关',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);e.setEnvironment('temperature',26,now);assert.equal(device(e).on,false);return '风扇先开后关';});
test('正常','规则开关重新计算','36°C→停用hot','风扇关闭',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);e.toggleRule('hot',now);assert.equal(device(e).on,false);return '风扇关闭';});
test('正常','删除规则重新计算','36°C→删除hot','风扇关闭且规则被移除',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);e.removeRule('hot',now);assert.equal(device(e).on,false);assert.equal(e.state.rules.length,2);return '风扇关闭且规则被移除';});
test('异常','无效阈值不修改状态','threshold=NaN','拒绝并保留原规则',()=>{const e=new CabinEngine();const r=new Rule();r.name='错误';r.threshold=NaN;assert.ok(e.saveRule(r,now));assert.equal(e.state.rules.length,3);return '拒绝并保留原规则';});
test('异常','空名及越界优先级','name为空；priority=100','均被拒绝',()=>{const r=new Rule();assert.ok(CabinEngine.validateRule(r));r.name='x';r.priority=100;assert.ok(CabinEngine.validateRule(r));return '均被拒绝';});
test('异常','环境越界输入','temperature=61, humidity=-1, light=Infinity','拒绝且环境未变',()=>{const e=new CabinEngine();const before=JSON.stringify(e.state.environment);assert.ok(e.setEnvironment('temperature',61,now));assert.ok(e.setEnvironment('humidity',-1,now));assert.ok(e.setEnvironment('light',Infinity,now));assert.equal(JSON.stringify(e.state.environment),before);return '拒绝且环境未变';});
test('边界','规则数量上限及编辑','20条规则后新增/编辑','新增拒绝，已有规则可编辑',()=>{const e=new CabinEngine();for(let i=3;i<20;i++){const r=new Rule();r.name='规则'+i;assert.equal(e.saveRule(r,now),'');} const r=new Rule();r.name='第21条';assert.ok(e.saveRule(r,now));r.id='hot';assert.equal(e.saveRule(r,now),'');assert.equal(e.state.rules.length,20);return '新增拒绝，已有规则可编辑';});
test('边界','传感器合法极值','temperature=-10/60; humidity=0/100; light=0/2000','全部接受',()=>{const e=new CabinEngine();for(const [key,values] of [['temperature',[-10,60]],['humidity',[0,100]],['light',[0,2000]]]){for(const v of values) assert.equal(e.setEnvironment(key,v,now),'');}return '全部接受';});
test('边界','日志去重及容量','重复计算；连续120次操作','重复联动不增日志，最多100条',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);const n=e.state.logs.length;e.evaluate(now);assert.equal(e.state.logs.length,n);for(let i=0;i<120;i++)e.control('fan',i%2===0,now);assert.equal(e.state.logs.length,100);return '重复联动不增日志，最多100条';});
test('正常','仿真反馈与采样','36°C，风扇开启后推进','温度34.8°C且采样tick=1',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);e.step(now);assert.equal(e.state.environment.temperature,34.8);assert.equal(e.state.samples[0].tick,1);return '温度34.8°C且采样tick=1';});
test('边界','仿真上下限与采样容量','极值输入后推进50次','数据不越界且仅保留12次采样',()=>{const e=new CabinEngine();e.setEnvironment('temperature',-10,now);e.control('fan',true,now);e.setEnvironment('humidity',100,now);e.control('pump',true,now);e.setEnvironment('light',2000,now);e.control('lamp',true,now);for(let i=0;i<50;i++)e.step(now);assert.equal(e.state.environment.temperature,-10);assert.equal(e.state.environment.humidity,100);assert.equal(e.state.environment.light,2000);assert.equal(e.state.samples.length,12);return '数据不越界且仅保留12次采样';});
test('正常','快照编码恢复','含规则、设备、环境、日志与采样的存档','JSON往返一致',()=>{const e=new CabinEngine();e.setEnvironment('temperature',36,now);e.step(now);const raw=StateCodec.encode(e.state);const d=StateCodec.decode(raw);assert.equal(d.recovered,true);assert.equal(StateCodec.encode(d.state),raw);return 'JSON往返一致（未验证系统Preferences落盘）';});
test('异常','损坏存档回退','{bad json / null / 缺字段','恢复初始配置并反馈损坏',()=>{for(const raw of ['{bad','null','{}']){const d=StateCodec.decode(raw);assert.equal(d.recovered,false);assert.match(d.message,/损坏/);}return '恢复初始配置并反馈损坏';});
test('异常','存档版本与数值校验','schemaVersion=2；temperature=null','拒绝非法存档',()=>{let s=CabinEngine.initial();s.schemaVersion=2;assert.equal(StateCodec.decode(JSON.stringify(s)).recovered,false);s=CabinEngine.initial();s.environment.temperature=null;assert.equal(StateCodec.decode(JSON.stringify(s)).recovered,false);return '拒绝非法存档';});
test('异常','重复规则ID与设备ID','重复hot；重复fan','拒绝非法存档',()=>{let s=CabinEngine.initial();s.rules.push(s.rules[0]);assert.equal(StateCodec.decode(JSON.stringify(s)).recovered,false);s=CabinEngine.initial();s.devices[1].id='fan';assert.equal(StateCodec.decode(JSON.stringify(s)).recovered,false);return '拒绝非法存档';});
const sourceFiles=['model/Models.ets','engine/CabinEngine.ets','storage/StateCodec.ets'];
const report={executedAt:new Date().toISOString(),runtime:process.version,scope:'实际ArkTS纯业务源码经TypeScript转译后在Node运行；不是设备实测',sourceHashes:Object.fromEntries(sourceFiles.map(f=>[f,crypto.createHash('sha256').update(fs.readFileSync(base+'/'+f)).digest('hex')])),passed:records.filter(r=>r.status==='PASS').length,total:records.length,records};
fs.mkdirSync(path.resolve(__dirname,'../docs/evidence'),{recursive:true});
fs.writeFileSync(path.resolve(__dirname,'../docs/evidence/unit-tests.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({passed:report.passed,total:report.total,failures:records.filter(r=>r.status==='FAIL')},null,2));
process.exitCode=report.passed===report.total?0:1;
