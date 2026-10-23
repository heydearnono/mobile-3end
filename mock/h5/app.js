// 三端共用的 H5，协议见 ../../spec.md「JSBridge 协议」「H5 测试用例」
(function () {
  'use strict';

  var testCase = new URLSearchParams(location.search).get('case');

  // case=blank：挂载前抛异常，#app 保持为空，应被判定为 empty_root
  if (testCase === 'blank') {
    throw new Error('[case=blank] simulated crash before mount');
  }

  // ---- bridge ----

  var seq = 0;
  var pending = {};
  var TIMEOUT_MS = 3000;

  function detectPlatform() {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.NativeBridge) return 'ios';
    if (window.NativeBridge && typeof window.NativeBridge.postMessage === 'function') return 'android-or-harmony';
    return 'none';
  }

  // 端差异只收敛在这里
  function postToNative(str) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.NativeBridge) {
      window.webkit.messageHandlers.NativeBridge.postMessage(str);
    } else if (window.NativeBridge && typeof window.NativeBridge.postMessage === 'function') {
      window.NativeBridge.postMessage(str);
    } else {
      throw new Error('NativeBridge not found');
    }
  }

  function callNative(method, params) {
    return new Promise(function (resolve, reject) {
      var id = String(++seq);
      var timer = setTimeout(function () {
        delete pending[id];
        reject({ code: 'TIMEOUT', message: method + ' no response in ' + TIMEOUT_MS + 'ms' });
      }, TIMEOUT_MS);
      pending[id] = { resolve: resolve, reject: reject, timer: timer };
      try {
        postToNative(JSON.stringify({ id: id, method: method, params: params || {} }));
      } catch (e) {
        clearTimeout(timer);
        delete pending[id];
        reject({ code: 'NO_BRIDGE', message: e.message });
      }
    });
  }

  window.__bridgeCallback = function (msg) {
    if (typeof msg === 'string') msg = JSON.parse(msg);
    var p = pending[msg.id];
    if (!p) return log('err', 'callback for unknown id ' + msg.id);
    clearTimeout(p.timer);
    delete pending[msg.id];
    msg.ok ? p.resolve(msg.data) : p.reject(msg.error);
  };

  window.__bridgeEvent = function (msg) {
    if (typeof msg === 'string') msg = JSON.parse(msg);
    log('ok', 'event ' + msg.event + ' ' + JSON.stringify(msg.data));
  };

  // ---- UI ----

  var logEl;

  function log(cls, text) {
    if (!logEl) return;
    var line = document.createElement('div');
    line.className = cls;
    line.textContent = new Date().toLocaleTimeString() + ' ' + text;
    logEl.prepend(line);
  }

  function run(method, params) {
    callNative(method, params).then(
      function (data) { log('ok', method + ' ok ' + JSON.stringify(data)); },
      function (err) { log('err', method + ' fail ' + JSON.stringify(err)); }
    );
  }

  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === 'onclick') node.addEventListener('click', attrs[k]);
      else node.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) {
      node.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    });
    return node;
  }

  function mount() {
    var deviceEl = el('pre', {}, ['…']);
    logEl = el('pre', {});

    var app = document.getElementById('app');
    app.appendChild(el('h1', {}, ['离线包测试页 case=' + (testCase || 'normal')]));
    app.appendChild(el('section', {}, [
      el('div', {}, ['location: ' + location.href]),
      el('div', {}, ['bridge: ' + detectPlatform()])
    ]));
    app.appendChild(el('section', {}, [el('div', {}, ['getDeviceInfo']), deviceEl]));
    app.appendChild(el('section', {}, [
      el('button', { onclick: function () { run('toast', { text: '来自 H5 的 toast' }); } }, ['toast']),
      el('button', { onclick: function () { run('notExist'); } }, ['不存在的方法']),
      el('button', { onclick: function () { run('getDeviceInfo'); } }, ['再取一次设备信息'])
    ]));
    app.appendChild(el('section', {}, [el('div', {}, ['日志（新的在上）']), logEl]));

    callNative('getDeviceInfo').then(
      function (data) { deviceEl.textContent = JSON.stringify(data, null, 2); deviceEl.className = 'ok'; },
      function (err) { deviceEl.textContent = JSON.stringify(err); deviceEl.className = 'err'; }
    );
  }

  // case=missing：请求包内不存在的资源，应触发 OFFLINE_404，页面其余部分正常
  if (testCase === 'missing') {
    var s = document.createElement('script');
    s.src = './missing.js';
    s.onerror = function () { log('err', 'missing.js load failed (expected)'); };
    document.head.appendChild(s);
  }

  // case=slow：3s 后才挂载，用来检验白屏检测时机
  if (testCase === 'slow') {
    setTimeout(mount, 3000);
  } else {
    mount();
  }
})();
