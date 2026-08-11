#!/usr/bin/env node
// Offline DOM smoke harness: intentionally provides no fetch/XMLHttpRequest/network APIs.
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const assert = require('assert');
const root = path.resolve(__dirname, '..', 'Job Tracker', 'Resources', 'WebMaps');
class Classes { constructor(n){this.n=n} add(...v){const s=new Set(this.n.className.split(/\s+/).filter(Boolean));v.forEach(x=>s.add(x));this.n.className=[...s].join(' ')} }
class Node { constructor(tag){this.tagName=tag;this.children=[];this.className='';this.style={};this.dataset={};this.attributes={};this.listeners={};this.clientWidth=800;this.clientHeight=600;this.classList=new Classes(this)} appendChild(n){this.children.push(n);n.parent=this;return n} remove(){if(this.parent)this.parent.children=this.parent.children.filter(x=>x!==this)} setAttribute(k,v){this.attributes[k]=String(v)} addEventListener(n,f){this.listeners[n]=f} querySelector(q){const match=n=>q==='svg'?n.tagName==='svg':q[0]==='.'&&n.className.split(' ').includes(q.slice(1));for(const c of this.children){if(match(c))return c;const x=c.querySelector(q);if(x)return x}return null} set innerHTML(v){this._html=v} get innerHTML(){return this._html||''} }
const map = new Node('div'); const status = new Node('div');
const document={createElement:t=>new Node(t),createElementNS:(_,t)=>new Node(t),getElementById:id=>id==='map'?map:id==='basemap-status'?status:null};
const messages=[]; const window={document,webkit:{messageHandlers:{mapEvent:{postMessage:m=>messages.push(m)}}}}; window.window=window;
const context=vm.createContext({window,document,console,setTimeout:f=>{f();return 1},clearTimeout,Map,Set,Date});
vm.runInContext(fs.readFileSync(path.join(root,'vendor/leaflet/leaflet.js'),'utf8'),context,{filename:'leaflet.js'});
context.L=window.L;
const html=fs.readFileSync(path.join(root,'FiberMap.html'),'utf8');
const inline=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(x=>x[1]).filter(x=>x.trim());
assert.equal(inline.length,1,'one application script should be present');
vm.runInContext(inline[0],context,{filename:'FiberMap.html'});
assert(window.FiberBridge,'JavaScript bridge initialized');
window.FiberBridge.applySnapshot({poles:[{id:'p1',name:'Pole 1',lat:36.32,lng:-88.95},{id:'p2',name:'Pole 2',lat:36.33,lng:-88.94}],splices:[{id:'s1',name:'Splice',lat:36.32,lng:-88.95,status:'Good'}],lines:[{id:'l1',startPoleId:'p1',endPoleId:'p2',status:'Active'}],jobs:[],visibleLayers:['poles','splices','lines','jobs']});
assert(map.querySelector('.leaflet-control-zoom'),'zoom controls initialized');
assert(map.querySelector('svg').children.length,'synced fiber shape initialized');
const tile=map.querySelector('.leaflet-tile'); assert(tile&&tile.onerror,'tile error handler initialized'); tile.onerror();
assert.equal(status.dataset.visible,'true','offline/error state visible');
assert(map.querySelector('svg').children.length,'fiber shape remains after basemap failure');
assert(map.querySelector('.leaflet-control-attribution').innerHTML.includes('OpenStreetMap'),'tile attribution remains visible');
assert(messages.some(x=>x.event==='mapReady')&&messages.some(x=>x.event==='basemapUnavailable'),'native bridge receives readiness and error events');
console.log('Fiber map offline resource smoke test passed');
