function freedjit(id) {
    $.get("http://localhost:4567/v",
        { title: document.title, url: document.URL },
        function(data) {},
        "jsonp");
    setInterval(
        function() {
	    $.get(
                "http://localhost:4567/list",
                {},
                function(data) {
                    $(id).html(data);
                },
                "jsonp");
        }, 5000);
}
