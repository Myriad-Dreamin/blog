<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <link rel="stylesheet" href="{{ URL::asset('css/navigator.css') }}">
    <link rel="stylesheet" href="{{ URL::asset('css/main.css') }}">
    @yield('extension_files')
    @yield('extension_metas')
</head>
<body>
    <div class="navigator">
		<ul>
			<li><a href="http://myriaddreamin.com">Home</a></li>
			<li><a href="http://myriaddreamin.com/articles">Article</a></li>
			<li><a href="https://github.com/Myriad-Dreamin">Code</a></li>
			<li><a href="http://myriaddreamin.com/secretlove">Mashmallo</a></li>
			<li><a href="http://myriaddreamin.com/chocolate">Chocolate</a></li>
		</ul>
        <div class="clear"></div>
    </div>
    
    <div>
    @yield('main_content')
    </div>
</body>
</html>