# 青禾智舱软件需求说明书

版本 1.0，2026-11-17。课程：移动应用开发基础。项目维护：张赟，20240313111，24物联1班。GitHub：sbz1121y-cell。项目采用 AI 辅助完成初始实现，实际个人贡献以本人后续审阅、修改、调试和提交记录为准。

## 1 应用场景和范围

青禾智舱是 HarmonyOS 智能温室规则仿真应用，对应指定主题三。用户在本地模拟温度、湿度、光照，通过规则驱动通风扇、灌溉泵和补光灯，再观察设备对下一次环境采样的影响。所有传感器与设备均为 Mock 数据，不连接真实硬件，不提供农业生产参数建议。

## 2 功能需求和验收条件

|编号|功能|验收条件|对应源码|
|---|---|---|---|
|F01|环境监测和模拟|三项指标可调整；拒绝越界值；场景预设会执行真实规则|Index.ets、CabinEngine.setEnvironment|
|F02|规则增删改和启停|名称1～20字符、阈值按传感器范围、优先级1～99；最多20条；编辑保留原启用状态|RuleEditor.ets、saveRule|
|F03|自动联动|大于或小于阈值才命中；同设备仅执行最高优先级规则；同优先级按ID升序|CabinEngine.evaluate|
|F04|设备控制|手动控制进入接管状态；交还自动后重新计算；离线拒绝控制，离线设备关闭|control、release、setOnline|
|F05|仿真反馈|每次推进计算设备造成的环境变化并保留最近12个采样|CabinEngine.step|
|F06|事件日志|记录联动、手动、规则、设备、系统、场景；最近100条；按类型筛选|EventLog、Index.logs|
|F07|持久化|主动操作后串行put与flush；重新启动恢复环境、规则、设备、日志和采样；读取失败不覆盖旧存档|CabinStore、StateCodec|
|F08|异常反馈|非法规则显示原因，离线设备不可操作，保存失败提示重试，损坏存档明确提示回退|RuleEditor、CabinStore|

F01～F08 已实现。24项纯业务测试和14项模拟器集成检查通过；Preferences实际落盘、规则优先级、设备控制、进程关闭重启恢复已在Huawei_Phone API17模拟器验证。原始存档、截图、屏幕采集和测试JSON均保存于docs/evidence。录屏为约每3秒一帧的真实屏幕采集，不作为动画性能测试证据。

## 3 整体架构与职责

页面层为 Index、RuleEditor 和 MetricTile；业务层为 CabinEngine；数据模型位于 Models；存储层由 CabinStore 调用 ArkData Preferences，StateCodec 校验快照；UIAbility 负责加载入口页面和后台保存。测试脚本直接加载 Models、CabinEngine、StateCodec 的实际源码。

单人项目的全部模块由张赟维护；初始源码由 AI 辅助生成。无其他学生组员。提交报告前须本人理解核心逻辑，并完成实际运行和必要的代码修改。

## 4 数据结构与存储

CabinState 包含 schemaVersion、Environment、Device[]、Rule[]、EventLog[]、Sample[]、automation、tick、sequence 和 savedAt。数据保存为一个 JSON 快照，Preferences 文件名称 qinghe_state，键 snapshot，版本号1。禁止在仓库提交设备签名私钥、证书或本地 SDK 路径。

温度范围 -10～60 °C，湿度 0～100%，光照 0～2000 lx。以上范围只用于演示输入校验。规则使用有限字符串类型定义指标、操作符与目标设备，避免任意字符串参与执行。

## 5 接口与执行规则

setEnvironment(key, value, now) 返回空串表示成功，否则返回错误信息；saveRule(rule, now) 在校验通过后保存规则并触发计算；evaluate(now) 无返回值并直接更新状态；control(id, on, now) 返回操作结果；step(now) 推进一次确定性仿真。时间字符串由调用方注入，测试可使用固定 Mock 时钟。

evaluate 先过滤启用规则，按优先级降序、ID升序排序，然后逐设备计算第一个命中的规则。手动接管或离线设备不参与自动计算；无规则命中的自动设备安全关闭；全局自动开关关闭时保留设备当前状态，直到用户操作或重新开启自动。关闭/开启规则或删除规则均重新计算。

每次推进时，风扇运行使温度减1.2，否则加0.4；灌溉泵运行使湿度加3，否则减0.8；补光灯运行使光照加60，否则减20。计算后钳制到输入范围，记录采样。该模型只用于展示因果关系。

## 6 非功能要求

使用 DevEco Studio 5.0.13.240、HarmonyOS 5.0.5 API17、ArkTS 和 Stage 模型。界面统一使用森林绿与浅灰绿。规则上限20、设备固定3个；规则计算复杂度 O(R log R + D×R)。仿真由用户点击推进，不在后台持续采样，不依赖网络。

存储写入串行执行，入队前获取不可变快照，避免旧写入覆盖新状态；flush 成功后才展示已保存。存档必须校验版本、类型、值域、设备完整性及规则ID唯一性，失败时使用初始配置并显示原因。

## 7 测试与展示计划

tests/run-tests.cjs 覆盖正常、边界、异常三类24项测试，结果保存在 docs/evidence/unit-tests.json。该测试在 Node 中转译实际纯业务 ArkTS 源码。模拟器另完成14项集成检查，报告为device-tests.json，覆盖场景与仿真、规则新增和冲突、手动接管、离线恢复、7项业务字段恢复、恢复后页面数值和自定义规则可见性。规则删除与修改具备源码和纯业务覆盖，尚未单独作为模拟器验收项记录。

## 8 参考资料

- Huawei Preferences 持久化：https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences/
- Huawei 工程构建配置：https://developer.huawei.com/consumer/en/doc/doccenter-deveco-studio/ide-hvigor-build-profile-app/
