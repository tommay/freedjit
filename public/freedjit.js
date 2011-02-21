function freedjit(id, key) {
    $.get("http://localhost:4567/visit",
        { key: key, title: document.title, url: document.URL },
        function(data) {},
        "jsonp");
    setInterval(
        function() {
	    $.get(
                "http://localhost:4567/list",
                { key: key },
                function(data) {
                    $(id).html(data);
                },
                "jsonp");
        }, 60000);
}
