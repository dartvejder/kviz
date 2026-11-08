// Service worker samo za obaveštenja domaćinu ("Ana je ušla u igru"). Ništa ne kešira.
self.addEventListener("install",()=>self.skipWaiting());
self.addEventListener("activate",e=>e.waitUntil(self.clients.claim()));
self.addEventListener("notificationclick",e=>{
  e.notification.close();
  e.waitUntil(self.clients.matchAll({type:"window",includeUncontrolled:true}).then(list=>{
    for(const c of list){ if(c.url.includes("/kviz")&&"focus" in c) return c.focus(); }
    return self.clients.openWindow("./");
  }));
});
