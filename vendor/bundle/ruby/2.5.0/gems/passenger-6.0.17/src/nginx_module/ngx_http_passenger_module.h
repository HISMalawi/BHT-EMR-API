/*
 * Copyright (C) Igor Sysoev
 * Copyright (C) 2007 Manlio Perillo (manlio.perillo@gmail.com)
 * Copyright (c) 2010-2018 Phusion Holding B.V.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _PASSENGER_NGINX_MODULE_H_
#define _PASSENGER_NGINX_MODULE_H_

#include <ngx_config.h>
#include <ngx_core.h>
#include "cxx_supportlib/WatchdogLauncher.h"
#include "cxx_supportlib/AppTypeDetector/CBindings.h"
#include "cxx_supportlib/Utils/CachedFileStat.h"

/**
 * The Nginx version number as an integer.
 * For example, on nginx 1.7.30 this value is 1007030.
 */
#define NGINX_VERSION_NUM \
    (1000000 * PASSENGER_NGINX_MAJOR_VERSION + \
     1000   * PASSENGER_NGINX_MINOR_VERSION + \
     PASSENGER_NGINX_MICRO_VERSION)

/* https://trac.nginx.org/nginx/ticket/1618 */
#if NGINX_VERSION_NUM >= 1015003
    #define NGINX_NO_SEND_REQUEST_BODY_INFINITE_LOOP_BUG
#endif

extern ngx_module_t ngx_http_passenger_module;

/**
 * A static schema string to be assigned to Nginx 'upstream' strctures.
 */
extern ngx_str_t                pp_schema_string;

extern ngx_str_t                pp_placeholder_upstream_address;

/** A CachedFileStat object used for caching stat() calls. */
extern PP_CachedFileStat        *pp_stat_cache;

extern PsgWrapperRegistry       *psg_wrapper_registry;

extern PsgAppTypeDetector       *psg_app_type_detector;

extern PsgWatchdogLauncher      *psg_watchdog_launcher;

extern ngx_cycle_t              *pp_current_cycle;

#endif /* _PASSENGER_NGINX_MODULE_H_ */
