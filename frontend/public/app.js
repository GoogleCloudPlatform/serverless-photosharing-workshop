var app = new Vue({
  el: '#app',
  data() {
    return { pictures: [] }
  },
  mounted() {
    axios
      .get('/api/pictures')
      .then(response => { this.pictures = response.data })
  }
})