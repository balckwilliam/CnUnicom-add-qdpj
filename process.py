import re
import sys
a=sys.argv[1]
print(a)
array=""
with open(a) as lines:
    array=lines.read().replace('\n', '').replace('\r', '')
    #array=lines.read()
    #print(array)
    #s1=re.findall(r".*?toDetailPage(\'(.*?)\'.*?\'(.*?)\'.*?activeBt",array,re.M|re.S)
    #s1=re.findall(r"toDetailPage.*?'(.*?)'.*?'(.*?)'.*?activeBt",array,re.M|re.S)
    #print(s1)
s1=re.findall(r"<a.*?toDetailPage\((.*?)\);.*?activeBt",array,re.M|re.S)
w=a+"ok"
with open(w,'a+') as f:
    for i in s1:
        f.write(i.replace('\'', '').replace(',', ' ')+"\n")
