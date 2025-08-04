import './bootstrap';
import { createApp } from 'vue';
import axios from 'axios';
import MapComponent from './components/MapComponent.vue';
import 'leaflet/dist/leaflet.css';
import '../css/app.css'

const app = createApp({});
app.config.globalProperties.$http = axios;
app.component('map-component', MapComponent);
app.mount('#app');