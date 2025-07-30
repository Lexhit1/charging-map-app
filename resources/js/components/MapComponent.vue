<template>
  <div>
    <l-map ref="map" :zoom="13" :center="center" style="height: 600px;">
      <l-tile-layer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"></l-tile-layer>
      <l-marker v-for="point in points" :key="point.id" :lat-lng="[point.location.coordinates[1], point.location.coordinates[0]]">
        <l-popup>
          <h3>{{ point.name }}</h3>
          <p>{{ point.description }}</p>
          <div v-for="comment in point.comments" :key="comment.id">{{ comment.comment }}</div>
          <input v-model="newComment" placeholder="Add comment" />
          <button @click="addComment(point.id)">Submit</button>
          <button @click="routeTo(point)">Route to here</button>
        </l-popup>
      </l-marker>
    </l-map>
    <button @click="addNewPoint">Add new point</button>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { LMap, LTileLayer, LMarker, LPopup } from '@vue-leaflet/vue-leaflet';
import L from 'leaflet';
import 'leaflet-routing-machine';
import axios from 'axios';

const map = ref(null);
const center = ref([51.505, -0.09]);
const points = ref([]);
const newComment = ref('');
let routingControl = null;

const fetchPoints = async () => {
  const response = await axios.get('/api/points');
  points.value = response.data.map(p => {
    const matches = p.location.match(/POINT\((.*) (.*)\)/);
    p.location = { coordinates: [parseFloat(matches[1]), parseFloat(matches[2])] };
    return p;
  });
};

const getUserLocation = () => {
  navigator.geolocation.getCurrentPosition(pos => {
    center.value = [pos.coords.latitude, pos.coords.longitude];
    fetchNearest(pos.coords.latitude, pos.coords.longitude);
  });
};

const fetchNearest = async (lat, lng) => {
  const response = await axios.get(`/api/points/nearest?lat=${lat}&lng=${lng}`);
  points.value = response.data;
};

const addComment = async (pointId) => {
  await axios.post('/api/comments', { point_id: pointId, comment: newComment.value });
  newComment.value = '';
  fetchPoints();
};

const routeTo = (point) => {
  if (routingControl) routingControl.remove();
  routingControl = L.Routing.control({
    waypoints: [
      L.latLng(center.value[0], center.value[1]),
      L.latLng(point.location.coordinates[1], point.location.coordinates[0])
    ]
  }).addTo(map.value.leafletObject);
};

const addNewPoint = () => {
  const name = prompt('Name:');
  const desc = prompt('Description:');
  navigator.geolocation.getCurrentPosition(async pos => {
    await axios.post('/api/points', {
      name, description: desc, lat: pos.coords.latitude, lng: pos.coords.longitude
    });
    fetchPoints();
  });
};

onMounted(() => {
  getUserLocation();
  fetchPoints();
});
</script>