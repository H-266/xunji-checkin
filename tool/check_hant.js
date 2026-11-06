const fs = require('fs');
const { convert } = require('./hant_convert');
const src = fs.readFileSync('lib/core/app_strings_generated.dart', 'utf8');
const keys = [];
for (const line of src.split('\n')) {
  const m = line.match(/^\s*"((?:[^"\\]|\\.)*)"\s*:/);
  if (m) {
    try { keys.push(JSON.parse('"' + m[1] + '"')); } catch (e) {}
  }
}
const simp = '设置数据任务备份导出导入默认信息网络视频文件夹保存加载刷新支持项目用户界面屏幕内存缓存服务器数据库在线离线账号登录注册密码软件硬件程序运行启动小组件备注新建创建添加打开切换后这们时个为务标签签删归档导备记录统计图热颜体帮电启错误复临办点编辑补网账软仓馈欢页项显调隐圆钟阅读长历华荣儿换发条卸载顶干传内对类现滚延迟吗节须跟说预题趋势单该经讯麦风闹独议骤荐绑将习构访暂划';
const remain = new Set();
for (const k of keys) {
  for (const ch of convert(k)) if (simp.includes(ch)) remain.add(ch);
}
console.log('input', keys.length, 'remaining simplified', [...remain].join(''));
