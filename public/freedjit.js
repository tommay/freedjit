function freedjit(id) {
    $.get("http://localhost:4567/v",
	  { title: document.title, url: document.URL });
    setInterval(
	function(){$(id).load("http://localhost:4567/list")},
	5000);
}
