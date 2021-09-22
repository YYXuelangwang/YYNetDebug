# -*- coding=utf-8 -*-
import os
import json
import urllib
import xml.dom.minidom
from xml.dom.minidom import Node
import ast

import re

class ErrorCode(object):
    OK = "HTTP/1.1 200 OK\r\n"
    NOT_FOUND = "HTTP/1.1 404 NOt Found\r\n"

class ContentType(object):
    HTML = "Content-Type: text/html\r\n"
    PNG = "Content-Type: img/png\r\n"
    JSON = "Content-Type: text/json\r\n"

class ParseMockXml(object):
    def __init__(self, path):
        self.path = path
        self.interfaces = {}
        self.singleParam = []
        self.multiParam = []
        self.parse(path)

    def parse(self, path):
        DOMTree = xml.dom.minidom.parse(path)
        root = DOMTree.documentElement
        nodes = root.childNodes
        for node in nodes:
            if node.nodeType == Node.ELEMENT_NODE:
                if node.tagName == "interface":
                    self.interfaces[node.childNodes[0].toxml().encode('utf-8')] = node.getAttribute("filterParams").encode('utf-8') if node.hasAttribute("filterParams") else ""
                elif node.tagName == "param":
                    self.singleParam.append(node.childNodes[0].toxml().encode('utf-8'))
                elif node.tagName == "params":
                    l = node.childNodes[0].toxml().encode('utf-8')
                    self.multiParam.append(l.split(","))

    def get_special_interface_params(self, interface, checkParams):
        """
            通过interface去字典中查找filterParams，
            如果没有，就返回interface本身；
            如果有，就将interface和filterParams拼接起来作为返回；
        """
        if  not interface or interface == "":
            return None
        if self.interfaces.has_key(interface):
            p = self.interfaces[interface]
            if p != "":
                if checkParams.find(p) > 0:
                    return interface + p
                else:
                    return None
            else:
                return interface
        else:
            return None

    def get_special_params_key(self, param):
        """
            通过传递进来的param，来和当前存储的singleParam，multiParams
            进行比较，singleParam在param中有存在，就返回singleParam对应的值；
            multiParams中单个数组，需要每个元素都在param中存在，就将单个数组中所有的元素拼接起来返回；
        """
        for s in self.singleParam:
            if param.find(s) > 0:
                return s
        
        r = False
        for array in self.multiParam:
            r = True
            for s in array:
                if param.find(s) < 0:
                    r = False
                    break
            if r:
                l = ""
                for s in array:
                    l = l + s
                return l
        
        return None

        
    def toJson(self):
        return {
            "interfaces":self.interfaces,
            "singleParam":self.singleParam,
            "multiParam":self.multiParam
        }

class HttpRequest(object):
    RootDir = 'root'
    NotFoundHtml = RootDir + '/' + '404.html'

    def __init__(self):
        self.method = None
        self.url = None
        self.protocol = None
        self.host = None
        self.request_data = None
        self.response_line = ErrorCode.OK   #响应吗
        self.response_head = ContentType.HTML   #响应头部
        self.response_body = '' #响应主题
        self.mock_data = None
        self.mock_interface_params = ParseMockXml("./config/mockdata.xml")

    # 解析请求，得到请求的信息
    def pass_request(self, request):
        request_line, body = request.split('\r\n', 1)
        header_list = request_line.split(' ')
        self.method = header_list[0].upper()
        self.url = header_list[1]
        #print self.url
        self.protocol = header_list[2]

        interface = ''
        req = ''

        #获取请求参数
        if self.method == 'POST':
            self.request_data = {}
            request_body = body.split('\r\n\r\n', 1)[1]
            parameters = request_body.split('\n') 
            for i in parameters:
                key, val = i.split('=')
                self.request_data[key] = val
            
            interface = self.url
            req = parameters
            # you can add some code, if you interest in;
        if self.method == 'GET':

            print self.url
            if re.match(r'^/mock_data$', self.url):
                self.response_line = ErrorCode.OK
                self.response_head = ContentType.JSON
                self.response_body = json.dumps(ParseMockXml("./config/mockdata.xml").toJson())
                return
            
            #获取get参数
            if self.url.find('?') != -1:
                self.request_data = {}
                req = self.url.split('?', 1)[1]
                interface = self.url.split('?', 1)[0]
                if interface == "/":
                    interface = ''
                req = urllib.unquote(req)
            else:
                interface = self.url

        self.handle_mocked_interface_paramters(interface, req)

    def handle_mocked_interface_paramters(self, interface, params):
        if not self.mock_data:
            self.mock_data = self.read_test_data2()

        backData = {}
        key = None
        if interface and interface != "":
            key = self.mock_interface_params.get_special_interface_params(interface, params)
            if not key and interface.startswith('/'):
                key = self.mock_interface_params.get_special_interface_params(interface[1:], params)
            # if key:
                # key = unicode(key, 'utf-8')
            if key and self.mock_data.has_key(key):
                backData = self.mock_data[key]
            else:
                print "interface or params error,\n interface:%s\n params:%s\n " % (interface, params)
        if params != "" and not key:
            key = self.mock_interface_params.get_special_params_key(params)
            # if key:
                # key = unicode(key, 'utf-8')
            if key and self.mock_data.has_key(key):
                backData = self.mock_data[key]
            else:
                print "params not match the param in config,\n params:%s\n " %  params

        self.response_line = ErrorCode.OK
        self.response_head = ContentType.JSON
        self.response_body = json.dumps(backData, encoding='utf-8', ensure_ascii=False)

    def read_test_data(self):
        f = open('./config/p_test_data.json')
        # 这里不使用json.loads方法，因为这个方法会导致字符串转为unicode
        dic = json.loads(f.read(), encoding='utf-8')
        f.close()
        return dic

    def read_test_data2(self):
        f = open('./config/p_test_data.json')
        dic = ast.literal_eval(f.read())
        f.close()
        return dic


    def get_response(self):
        return self.response_line + self.response_head + '\r\n' + self.response_body