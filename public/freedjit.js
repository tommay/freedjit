function freedjit(id) {
    $.get("http://localhost:4567/v",
	  { title: document.title, url: document.URL });
    setInterval(
        function() {
	    $.ajax({
                url: "http://localhost:4567/list",
                dataType: "jsonp",
                success: function(data) {
                    $(id).html(data);
                }
            });
        }, 5000);
}
