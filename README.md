# hjl_lua

nginx 配置
http{
        lua_package_path  "/data/hjl_lua/store/?.lua;/data/hjl_lua/common/?.lua;/data/hjl_lua/lib/?.lua;;";
        lua_package_cpath "/data/hjl_lua/common/?.so;/data/hjl_lua/lib/?.so;;";
        lua_shared_dict my_limit_req_store 256m; #限流模块共享内存
        lua_shared_dict srcache_lock 10m; #srcache共享内存锁
        lua_shared_dict srcache_data 256m; #srcache缓存数据
        init_by_lua_file "/data/hjl_lua/store/init.lua";
}

server {
  
    lua_code_cache off;

    location  /test {
        access_by_lua_file  "/data/hjl_lua/store/test.lua";
    }


    location / {
        access_by_lua_file  "/data/hjl_lua/store/access.lua";
        try_files $uri $uri/ /index.php$uri$is_args$args;
    }

    location ~ [^/]\.php(/|$) {
        internal;
        #srcache config
        set $key "";
        set $ttl 600; #缓存默认过期时间
        set $skip 1;
        rewrite_by_lua_file "/data/hjl_lua/store/srcache_rewrite.lua";
        srcache_response_cache_control off;
        srcache_fetch_skip $skip;
        srcache_store_skip $skip;
        srcache_store_statuses 200;
        srcache_fetch GET /srcacheRedis key=$key;
        srcache_store PUT /srcacheRedis key=$key&ttl=$ttl;
        add_header X-Srcache-Fetch $srcache_fetch_status;
        add_header X-Srcache-Store $srcache_store_status;

        include fastcgi_params;
        include pathinfo.conf;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
    }

    location /srcacheRedis {
        internal;
        content_by_lua_file "/data/hjl_lua/store/srcache_content.lua";
    }

}
