function freedjit(id, key) {
    $.get(
        "http://localhost:4567/visit",
        { key: key, title: document.title, url: document.URL },
        function(data) {},
        "jsonp");
    var list = function() {
        $.get(
            "http://localhost:4567/list",
            { key: key },
            function(data) {
                $(id).html(data);
            },
            "jsonp");
    };
    list();
    setInterval(list, 60000);
}
