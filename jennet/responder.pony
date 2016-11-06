// Copyright 2016 Theodore Butler. All rights reserved.
// Use of this source code is governed by an MIT style
// license that can be found in the LICENSE file.

use "net/http"
use "term"
use "time"

interface val Responder
  """
  Responds to the request and creates a log.
  """
  fun val apply(req: Payload, res: Payload, response_time: U64, host: String)

class DefaultResponder is Responder
  let _out: OutStream

  new val create(out: OutStream) =>
    _out = out

  fun val apply(req: Payload, res: Payload, response_time: U64, host: String) =>
    let time = Date(Time.seconds()).format("%d/%b/%Y %H:%M:%S")
    let list = recover Array[String](17) end
    list.push("[")
    list.push(host)
    list.push("] ")
    list.push(time)
    list.push(" |")
    let status = res.status
    list.push(
      if (status >= 200) and (status < 300) then
        ANSI.bright_green()
      elseif (status >= 300) and (status < 400) then
        ANSI.bright_blue()
      elseif (status >= 400) and (status < 500) then
        ANSI.bright_yellow()
      else
        ANSI.bright_red()
      end)
    list.push(status.string())
    list.push(ANSI.reset())
    list.push("| ")
    list.push(_format_time(response_time))
    list.push(" | ")
    list.push(req.method)
    list.push(" ")
    list.push(req.url.path)
    list.push("\n")
    _out.writev(consume list)
    (consume req).respond(consume res)

  fun _format_time(response_time: U64): String =>
    var padding = "       "
    let time = recover iso response_time.string() end
    var unit = "ns"
    let s = time.size()

    if s < 4 then
      None
    elseif s < 7 then
      time.insert_in_place(s.isize() - 3, ".")
      unit = "µs"
    elseif s < 10 then
      time.insert_in_place(s.isize() - 6, ".")
      unit = "ms"
    else
      time.insert_in_place(s.isize() - 9, ".")
      unit = "s "
    end
    try
      let i = time.find(".")
      time.cut_in_place(i + 3)
    end
    padding = padding.substring(time.size().isize())
    
    let str = recover String(padding.size() + time.size() + unit.size()) end
    str.append(padding)
    str.append(consume time)
    str.append(unit)
    consume str

class CommonResponder is Responder
  """
  Logs HTTP requests in the common log format.
  """
  let _out: OutStream

  new val create(out: OutStream) =>
    _out = out

  fun val apply(req: Payload, res: Payload, response_time: U64, host: String) =>
    let list = recover Array[String](24) end
    list.push(host)
    list.push(" - ")
    let user = req.url.user
    list.push(if user.size() > 0 then user else "-" end)
    list.push(" [")
    list.push(Date(Time.seconds()).format("%d/%b/%Y:%H:%M:%S +0000"))
    list.push("] \"")
    list.push(req.method)
    list.push(" ")
    list.push(req.url.path)
    if req.url.query.size() > 0 then
      list.push("?")
      list.push(req.url.query)
    end
    if req.url.fragment.size() > 0 then
      list.push("#")
      list.push(req.url.fragment)
    end
    list.push(" ")
    list.push(req.proto)
    list.push("\" ")
    list.push(res.status.string())
    list.push(" ")
    list.push(res.body_size().string())
    list.push(" \"")
    try list.push(req("Referrer")) end
    list.push("\" \"")
    try list.push(req("User-Agent")) end
    list.push("\"\n")
    _out.writev(consume list)
    (consume req).respond(consume res)