# -*- coding=utf-8 -*-

import socket
import threading
import os
from HttpRequest import HttpRequest
from HttpRequest import ParseMockXml

def tcp_link(sock, addr):
    print 'Accept new connection from %s:%s...' % addr
    request = sock.recv(20480)
    http_req = HttpRequest()
    http_req.pass_request(request)
    # 发送数据
    sock.send(http_req.get_response())
    sock.close()

def start_server():
    port = os.popen('cat ./config/port.txt').read()
    print 'local ip address : %s:%s' % (socket.gethostbyname(socket.gethostname()), port)

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # 监听端口
    s.bind(('', int(port)))
    s.listen(5)
    while True:
        sock, addr = s.accept()
        t = threading.Thread(target=tcp_link, args=(sock, addr))
        t.start()

if __name__ == '__main__':
    start_server()
    pass