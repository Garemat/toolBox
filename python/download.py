import requests
import os
import argparse
from urllib.parse import urlparse
import zipfile
from xml.dom import minidom
from xml.dom.minidom import Node

#Reads arguments from command line
def get_args():
    parser = argparse.ArgumentParser(description='Download files from repo')
    parser.add_argument('-v', '--version', type=str, help='Version number of artifacts.',required=True)
    parser.add_argument('-u', '--username', type=str, help='Enter username for Nexus', required=True)
    parser.add_argument('-p', '--password', type=str, help='Enter password for Nexus', required=True)
    parser.add_argument('-f', '--xmlDoc', type=str, help='XML config document', required=True)
    parser.add_argument('-d', '--outputDirectory', type=str, help='Where to place downloaded artifacts', required=True)

    args = parser.parse_args()

    version = args.version
    username = args.username
    password = args.password
    xmlDoc = args.xmlDoc
    outputDirectory = args.outputDirectory
    return version, username, password, xmlDoc, outputDirectory

#Function to make reading nodes a little easier
def getNodeText(node):
    nodelist = node.childNodes
    result = []
    for node in nodelist:
        if node.nodeType == node.TEXT_NODE:
            result.append(node.data)
    return ''.join(result)

#Stores command line parameters to vars
version_number, uname, passwd, xmlDoc, outputDirectory = get_args()

#parses the xml document passed as parameter
doc = minidom.parse(xmlDoc)

#Reads the name and repository
name = doc.getElementsByTagName("application")[0]
repo = doc.getElementsByTagName("repo")[0]

#Generic output for validation that it read the right stuff
print("Application: %s" % getNodeText(name))
print("Repository: %s \n" % getNodeText(repo))

#Stores all the artifact nodes to array
artifacts = doc.getElementsByTagName("artifact")

#This arry will contain full url to pull artifact
urlList = []

#Start stripping out elements of artifact nodes
#Use getAttribute("tag") to pull any nested values
for art in artifacts:
        artifact = art.getElementsByTagName("name")[0]
        ext = art.getElementsByTagName("extension")[0]
        #Some more generic output for validation that it's picked up the right stuff
        print("artifact: %s.%s" % (getNodeText(artifact), getNodeText(ext)))
        urlList.append(getNodeText(repo) + getNodeText(artifact) + '/' + version_number + '/' + getNodeText(artifact) + '-' + version_number + '.' + getNodeText(ext))

for url in urlList:
    filename = os.path.basename(urlparse(url).path)
    req = requests.get(url, auth=(uname, passwd))
    print(req.status_code)
    print(url)
    if req.status_code == 200:
        with open(outputDirectory + filename, 'wb') as out:
            for bits in req.iter_content():
                out.write(bits)
