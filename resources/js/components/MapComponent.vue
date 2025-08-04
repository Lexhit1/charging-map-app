
<template>
  <div>
    <div class="map-header" style="margin-bottom:8px;">
      <span v-if="user">
        👤 Привет, {{ user.username }}! | <b>Точек добавлено:</b> {{ user.points_created }}
        <button @click="logout">🗝️ Выйти</button>
      </span>
      <span v-else>
        <button @click="openAuth('login')">Войти</button> |
        <button @click="openAuth('register')">Регистрация</button>
      </span>
      <button v-if="user" @click="enableAddMode" :disabled="addingPoint" style="margin-left:16px;">➕ Добавить точку</button>
    </div>

    <l-map
      ref="map"
      :zoom="zoom"
      :center="center"
      style="height: 600px"
      @click="onMapClick"
    >
      <l-tile-layer :url="tileLayer"></l-tile-layer>

      <l-marker
        v-for="point in points"
        :key="point.id"
        :lat-lng="pointLatLng(point)"
        :icon="plugIcon(point.type)"
      >
        <l-popup>
          <div>
            <h4><b>{{ point.name }}</b></h4>
            <div v-if="point.type==='green'">🟢 Бесплатно</div>
            <div v-else-if="point.type==='yellow'">🟡 За кофе/печеньку</div>
            <div v-else>🔴 Платно</div>
            <div><small>@<b>{{point.user?.username||'Аноним'}}</b> (добавил {{ point.user?.points_created||'?' }} точек)</small></div>
            <div v-if="point.address">📍 {{ point.address }}</div>
            <div>{{ point.description }}</div>
            <div v-if="point.photo_url"><img :src="point.photo_url" style="max-width:80px;max-height:80px;"></div>
            <div style="margin:6px 0;"><b>Комментарии:</b></div>
            <div v-for="c in point.comments" :key="c.id" style="font-size:14px">
              <i>{{ c.user?.username||'Аноним' }}:</i> {{ c.comment }}
            </div>
            <div v-if="user" style="margin-top:6px;">
              <textarea v-model="newComment[point.id]" placeholder="Комментарий" rows="1"></textarea>
              <button @click="submitComment(point.id)">Отправить</button>
            </div>
            <div v-if="user" style="margin-top:6px;">
              <input type="file" @change="onPhotoSelected($event, point.id)" />
            </div>
            <button v-if="user" @click="routeTo(point)">Маршрут до сюда</button>
          </div>
        </l-popup>
      </l-marker>

      <l-marker v-if="addingPoint && newLatLng" :lat-lng="newLatLng" :icon="plugIcon(newPoint.type)">
        <l-popup>
          <div>
            <input v-model="newPoint.name" placeholder="Название" /><br/>
            <input v-model="newPoint.description" placeholder="Описание" /><br/>
            <select v-model="newPoint.type">
              <option value="green">Бесплатно</option>
              <option value="yellow">За кофе/печеньку</option>
              <option value="red">Платно</option>
            </select><br/>
            <button @click="confirmAddPoint">Добавить на эту точку</button>
            <button @click="cancelAddPoint">Отмена</button>
          </div>
        </l-popup>
      </l-marker>
    </l-map>

    <div v-if="authDialog" class="modal">
      <div class="modal-content">
        <h3>{{ authMode==='login'?'Вход':'Регистрация' }}</h3>
        <input v-model="authData.username" placeholder="Логин" />
        <input v-model="authData.password" placeholder="Пароль (4-8 цифр)" maxlength="8" type="password" />
        <button @click="submitAuth">{{ authMode==='login'?'Войти':'Зарегистрироваться' }}</button>
        <button @click="closeAuth">Отмена</button>
        <div v-if="authError" style="color:red; margin-top:8px;">{{ authError }}</div>
      </div>
    </div>
  </div>
</template>

<script>
import { LMap, LTileLayer, LMarker, LPopup } from '@vue-leaflet/vue-leaflet';
import L from 'leaflet';
import axios from 'axios';
import plugGreen from '/public/img/plug-green.png';
import plugYellow from '/public/img/plug-yellow.png';
import plugRed from '/public/img/plug-red.png';

export default {
  name: 'MapComponent',
  components: { LMap, LTileLayer, LMarker, LPopup },
  data() {
    return {
      tileLayer: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      zoom: 12,
      center: [59.93, 30.31],
      user: null,
      token: localStorage.getItem("token")||null,
      points: [],
      addingPoint: false,
      newLatLng: null,
      newPoint: { name:"",description:"",type:"green" },
      newComment: {},
      authDialog: false,
      authMode: 'login',
      authData: { username:"",password:"" },
      authError: "",
      plugIcons: {
        green: L.icon({ iconUrl: plugGreen, iconSize:[40,40], iconAnchor:[20,40] }),
        yellow: L.icon({ iconUrl: plugYellow, iconSize:[40,40], iconAnchor:[20,40] }),
        red: L.icon({ iconUrl: plugRed, iconSize:[40,40], iconAnchor:[20,40] }),
      },
    };
  },
  mounted() {
    if(this.token) {
      axios.get('/api/user',{ headers:{ Authorization:`Bearer ${this.token}` } })
        .then(res=>this.user=res.data)
        .catch(()=>{ localStorage.removeItem('token'); this.user=null; });
    }
    this.fetchPoints();
    this.$nextTick(()=>{ this.$refs.map?.mapObject.invalidateSize(); });
  },
  methods: {
    plugIcon(t){ return this.plugIcons[t]||this.plugIcons.green; },
    pointLatLng(p) {
      const m=String(p.location).match(/POINT\(([-\d.]+) ([-\d.]+)\)/);
      return m?[parseFloat(m[2]),parseFloat(m[1])]:null;
    },
    async fetchPoints(){ this.points=(await axios.get("/api/points")).data; },
    openAuth(m){ this.authDialog=true; this.authMode=m; this.authData={username:"",password:""}; this.authError=""; },
    closeAuth(){ this.authDialog=false; this.authError=""; this.$nextTick(()=>this.$refs.map?.mapObject.invalidateSize()); },
    async submitAuth() {
      try {
        const url=this.authMode==='login'?'/api/login':'/api/register';
        const res=await axios.post(url,this.authData);
        this.token=res.data.token; this.user=res.data.user;
        localStorage.setItem('token',this.token);
        this.closeAuth(); this.fetchPoints();
      } catch(e) { this.authError=e.response?.data?.message||'Ошибка авторизации'; }
    },
    logout(){ localStorage.removeItem('token'); this.token=null; this.user=null; },
    enableAddMode(){ this.addingPoint=true; this.newLatLng=null; this.newPoint={name:"",description:"",type:"green"}; },
    onMapClick(e){ if(this.addingPoint&&!this.newLatLng) this.newLatLng=[e.latlng.lat,e.latlng.lng]; },
    async confirmAddPoint() {
      if(!this.user){ alert("Авторизуйтесь для добавления точки."); return; }
      const {name,description,type}=this.newPoint;
      if(!name||!description){ alert("Укажите название и описание!"); return; }
      try {
        await axios.post('/api/points',{name,description,type,lat:this.newLatLng[0],lng:this.newLatLng[1]},
          { headers:{ Authorization:`Bearer ${this.token}` } });
        this.addingPoint=false; this.newLatLng=null; this.fetchPoints();
        alert("Точка добавлена!");
      } catch(e){ alert(e.response?.data?.message||"Ошибка добавления точки"); }
    },
    cancelAddPoint(){ this.addingPoint=false; this.newLatLng=null; },
    async submitComment(id){
      if(!this.user){ alert("Только авторизованные пользователи могут оставлять комментарии."); return; }
      const c=this.newComment[id]; if(!c) return;
      try {
        await axios.post('/api/comments',{point_id:id,comment:c},{headers:{Authorization:`Bearer ${this.token}`}});
        this.newComment[id]=""; this.fetchPoints();
      } catch(e){ alert(e.response?.data?.message||"Ошибка добавления комментария"); }
    },
    onPhotoSelected(e,id){
      const f=e.target.files[0]; if(!f) return;
      const fd=new FormData(); fd.append('photo',f);
      axios.post(`/api/points/${id}/photo`,fd,
        { headers:{ Authorization:`Bearer ${this.token}`, 'Content-Type':'multipart/form-data' } })
        .then(()=>this.fetchPoints()).catch(e=>alert(e.response?.data?.message||"Ошибка загрузки фото"));
      alert("Фото отправлено (если backend готов)");
    },
    routeTo(){ alert("Маршруты пока не реализованы — подключи leaflet-routing-machine."); },
  },
};
</script>

<style>
.map-header { display:flex; align-items:center; gap:8px; font-size:16px; margin:12px 0; }
.modal { position:fixed; top:0; left:0; width:100vw; height:100vh; background:rgba(0,0,0,0.2); display:flex; align-items:center; justify-content:center; z-index:1000; }
.modal-content { background:#fff; padding:2em; border-radius:1em; min-width:280px; box-shadow:0 8px 40px #0002; }
</style>