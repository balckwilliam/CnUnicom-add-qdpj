#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:
## wget --no-check-certificate https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh && chmod +x CnUnicom.sh && bash CnUnicom.sh 
### bash <(curl -s https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh) ${username} ${password}

# alias curl
alias curl='curl -m 10'

# user info: change them to yours or use parameters instead.
username="$1"
password="$2"

# UA and deviceId: if you failed to login , maybe you need to change it to your IMEI.
deviceId=$(shuf -i 123456789012345-987654321012345 -n 1)


# 安卓手机端APP登录过的使用这个UA
UA="Mozilla/5.0 (Linux; Android 6.0.1; oneplus a5010 Build/V417IR; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/52.0.2743.100 Mobile Safari/537.36; unicom{version:android@6.0100,desmobile:$username};devicetype{deviceBrand:Oneplus,deviceModel:oneplus a5010}"

# 苹果手机端APP登录过的使用这个UA
#UA="ChinaUnicom4.x/176 CFNetwork/1121.2.2 Darwin/19.2.0"

# workdir
workdir="/root/CnUnicom_$username/"
[[ ! -d "$workdir" ]] && mkdir $workdir

function rsaencrypt() {
    cat > $workdir/rsa_public.key <<-EOF
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDc+CZK9bBA9IU+gZUOc6
FUGu7yO9WpTNB0PzmgFBh96Mg1WrovD1oqZ+eIF4LjvxKXGOdI79JRdve9
NPhQo07+uqGQgE4imwNnRx7PFtCRryiIEcUoavuNtuRVoBAm6qdB0Srctg
aqGfLgKvZHOnwTjyNqjBUxzMeQlEC2czEMSwIDAQAB
-----END PUBLIC KEY-----
EOF

    crypt_username=$(echo -n $username | openssl rsautl -encrypt -inkey $workdir/rsa_public.key -pubin -out >(base64 | tr "\n" " " | sed s/[[:space:]]//g))
    crypt_password=$(echo -n $password | openssl rsautl -encrypt -inkey $workdir/rsa_public.key -pubin -out >(base64 | tr "\n" " " | sed s/[[:space:]]//g))
}

function urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
        esac
    done
}

function login() {
    rsaencrypt
    cat > $workdir/signdata <<-EOF
isRemberPwd=true
&deviceId=$deviceId
&password=$(urlencode $crypt_password)
&simCount=0
&netWay=Wifi
&mobile=$(urlencode $crypt_username)
&yw_code: 
&timestamp=$(date +%Y%m%d%H%M%S)
&appId=db5c52929cc2d7f5c46272487e926aebfb82b3bad6b9cd07f1eb99b6a6f34a90
&keyVersion=1
&deviceBrand=Oneplus
&pip=10.0.$(shuf -i 1-255 -n 1).$(shuf -i 1-255 -n 1)
&provinceChanel=general
&version=android%406.0100
&deviceModel=oneplus%20a5010
&deviceOS=android6.0.1
&deviceCode=$deviceId
EOF

    # cookie
    curl -sA "$UA" -D $workdir/cookie "https://m.client.10010.com/mobileService/logout.htm" >/dev/null
    curl -sA "$UA" -b $workdir/cookie -c $workdir/cookie -d @$workdir/signdata "http://m.client.10010.com/mobileService/login.htm" >/dev/null
    token=$(cat $workdir/cookie | grep -E "a_token" | awk  '{print $7}')
    [[ "$token" = "" ]] && echo "Error, login failed." && echo "cmd for clean: rm -rf $workdir" && exit 1
}

function openChg() {
    # openChg for dingding 1 time each month. Just for me!
    [[ $(date | awk '{print $3}') -eq 1 ]] || return 0
    echo; echo $(date) starting dingding OpenChg...
    curl -sA "$UA" -b $workdir/cookie --data "querytype=02&opertag=0" "https://m.client.10010.com/mobileService/businessTransact/serviceOpenCloseChg.htm" >/dev/null
}

function membercenter() {
    echo; echo $(date) starting membercenter...   
    #获取文章和评论生成数组数据
    NewsListId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "pageNum=1&pageSize=10&reqChannel=00" https://m.client.10010.com/commentSystem/getNewsList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    comtId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    nickId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "nickName\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    Referer="https://img.client.10010.com/kuaibao/detail.html?pageFrom=${NewsListId[0]}"
    #评论点赞
    for((i = 0; i < ${#comtId[*]}; i++)); do
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=02&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=01&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise | grep -oE "growScore\":\"0\"" >/dev/null && break
    done
    #文章点赞
    for((i = 0; i <= ${#NewsListId[*]}; i++)); do
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=02&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=01&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise | grep -oE "growScore\":\"0\"" >/dev/null && break
    done
    #账单查询
    if [[ $(date "+%d") -eq 1 ]]; then
        curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.HistoryBill --data "desmobile=$username&version=android@7.0000" "https://m.client.10010.com/mobileService/common/skip/queryHistoryBill.htm?mobile_c_from=home" >/dev/null
        curl -sLA "$UA" -b $workdir/cookie.HistoryBill --data "operateType=0&bizCode=1000210003&height=889&width=480" "https://m.client.10010.com/mobileService/query/querySmartBizNew.htm?" >/dev/null
        curl -sLA "$UA" -b $workdir/cookie.HistoryBill --data "systemCode=CLIENT&transId=&userNumber=$username&taskCode=TA52554375&finishTime=$(date +%Y%m%d%H%M%S)" "https://act.10010.com/signinAppH/limitTask/limitTime" >/dev/null
    fi 
    #签到
    Referer="https://img.client.10010.com/activitys/member/index.html"
    curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.SigninActivity -e "$Referer" https://act.10010.com/SigninApp/signin/querySigninActivity.htm >/dev/null
    Referer="https://act.10010.com/SigninApp/signin/querySigninActivity.htm"
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/rewardReminder.do?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)" >/dev/null
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" --data "className=signinIndex" https://act.10010.com/SigninApp/signin/daySign.do
    curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "transId=$(date +%Y%m%d%H%M%S)$(shuf -i 0-9 -n 1).$(shuf -i 123456789012345-987654321012345 -n 1)&userNumber=$username&taskCode=TA590934984&finishTime=$(date +%Y%m%d%H%M%S)&taskType=DAILY_TASK" https://act.10010.com/signinAppH/commonTask
    ##获取金币
    for((i = 0; i <= ${#NewsListId[*]}; i++)); do
        curl -sA "$UA" -b $workdir/cookie --data "newsId=$(echo "ff808081695a52b1016"$(date +%s%N | md5sum | head -c 13))" "http://m.client.10010.com/mobileService/customer/quickNews/shareSuccess.htm" | grep -oE "jbCount\":\"\"" >/dev/null && break
    done  
    ##金币抽奖：3 times free each day and 13 times total.
    usernumberofjsp=$(curl -sA "$UA" -b $workdir/cookie.SigninActivity http://m.client.10010.com/dailylottery/static/textdl/userLogin | grep -oE "encryptmobile=\w*" | awk -F"encryptmobile=" '{print $2}')
    for((i = 1; i <= 3; i++)); do
        [[ $i -gt 3 ]] && curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "goldnumber=10&banrate=10&usernumberofjsp=$usernumberofjsp" http://m.client.10010.com/dailylottery/static/doubleball/duihuan >/dev/null; sleep 1
        curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "usernumberofjsp=$usernumberofjsp" http://m.client.10010.com/dailylottery/static/doubleball/choujiang | grep -oE "用户机会次数不足" >/dev/null && break
    done
    echo goldTotal：$(curl -sA "$UA" -b $workdir/cookie.SigninActivity "https://act.10010.com/SigninApp/signin/goldTotal.do")
}

function wangzuan() {
    # wangzuan: 1 time free each month.
    [[ $(date "+%d") -eq 1 ]] || return 0
    echo; echo $(date) starting wangzuan...
    data="timestamp=$(date +%Y%m%d%H%M%S)&desmobile=$username&version=android%406.0100"
    curl -L -sA "$UA" -b $workdir/cookie -c $workdir/cookie_wz --data "$data" "https://m.client.10010.com/mobileService/openPlatform/openPlatLine.htm?to_url=https://wangzuan.10010.com/api/auth/login?source=2" >/dev/null
    echo wangzuan_status：$(curl -X POST -sA "$UA" -b $workdir/cookie_wz https://wangzuan.10010.com/api/activity/lottery)
}

function club() {
    echo; echo; echo $(date) starting club...
    data="timestamp=$(date +%Y%m%d%H%M%S)&desmobile=$username&version=android%406.0100"
    curl -i -sLA "$UA" -b $workdir/cookie -c $workdir/cookie_cl --data "$data" "https://m.client.10010.com/mobileService/openPlatform/openPlatLine.htm?to_url=https://club.10010.com/index.html" >$workdir/clubsign.log
    ticket=$(cat $workdir/clubsign.log | grep -oE "ticket=\w*" | awk -F'[=]' '{print $2}')
    data="ticket=$ticket&channel=woapp&accesstoken=$(date +%s%N | md5sum | head -c 23)"
    accesstoken=$(curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "$data" https://club.10010.com/api/member/channellogin | grep -oE "accesstoken\":\"\w*" | awk -F'["]' '{print $3}')
  
    # sign
    curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "accesstoken=$accesstoken" https://club.10010.com/api/member/sign
    curl -X POST -sA "$UA" -b $workdir/cookie_cl -e "https://club.10010.com/index.html" -H 'content-type: application/json' --data "{}" -H "AuthToken: MEM_$accesstoken" https://club.10010.com/newactivity/unicom/cms/actobj/signin/signin
	
    # praise
    list=($(echo $(curl -i -sA "$UA" -b $workdir/cookie --data "accesstoken=$accesstoken" https://club.10010.com/api/pub/toplist/ | grep -oE "\"code\":\"\w*" | awk -F'["]' '{print $NF}')))
    data="page=1&order=&accesstoken=$accesstoken"
    list_c=($(echo $(curl -i -sA "$UA" -b $workdir/cookie --data "$data" "https://club.10010.com/api/pub/comments/${list[1]}" | grep -oE "\"code\":\"\w*" | awk -F'["]' '{print $NF}')))
    for((i = 1; i <= 4; i++)); do
        echo praise_status_$i：$(curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "type=pub&accesstoken=$accesstoken" https://club.10010.com/api/pub/praise/${list[i]}) ; sleep 1
        echo praise_comment_$i：$(curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "type=comment&accesstoken=$accesstoken" https://club.10010.com/api/pub/praise/${list_c[i]}) ; sleep 1
    done

    # view
    parentcode=$(curl -i -sA "$UA" -b $workdir/cookie --data "accesstoken=$accesstoken" https://club.10010.com/api/japi/portal/getselectsetting | grep -oE "\"data\":\"\w*" | awk -F'["]' '{print $NF}')
    data="parentcode=$parentcode&accesstoken=$accesstoken"
    list=($(echo $(curl -i -sA "$UA" -b $workdir/cookie --data "$data" https://club.10010.com/api/pub/pubincollist | grep -oE "\"code\":\"\w*" | awk -F'["]' '{print $NF}' | shuf)))
    for((i = 1; i <= 6; i++)); do
        echo view_status_$i：$(curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "accesstoken=$accesstoken" https://club.10010.com/api/pub/info/${list[i]} | grep -oE "\"code\":\w*" | awk -F'[:]' '{print $2}') ; sleep 1
    done

    # 其它任务
    taskcode=$(cat $workdir/clubsign.log | grep -E "window.taskcode" | awk -F'[\"]' '{print $((NF-1))}')
    membercode=($(curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "accesstoken=$accesstoken" https://club.10010.com/api/japi/portal/getrecommendmem | grep -oE "\"code\":\"[^\"]*" | awk -F'[\"]' '{print $NF}' | head -n5 | tr '\n' ' '))
    for((i = 0; i < ${#membercode[*]}; i++)); do
        sleep $(shuf -i 3-5 -n 1)
        curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "membercode=${membercode[i]}&accesstoken=$accesstoken" https://club.10010.com/api/japi/member/follow
        sleep $(shuf -i 3-5 -n 1)
	curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "membercode=${membercode[i]}&accesstoken=$accesstoken" https://club.10010.com/api/japi/member/cancelfollow
    done
    for((i = 0; i < 30; i++)); do
        sleep $(shuf -i 3-5 -n 1)
        curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "action=$i&target=&accesstoken=$accesstoken" https://club.10010.com/api/japi/portal/actionrecord >/dev/null
        sleep $(shuf -i 3-5 -n 1)
	curl -X POST -sA "$UA" -b $workdir/cookie_cl --data "type=$i&code=$taskcode&accesstoken=$accesstoken" https://club.10010.com/api/japi/portal/completetask >/dev/null
    done
}

function qychinaunicom() {
    echo; echo $(date) starting qychinaunicom...
    data="yw_code=&desmobile=$username&version=android%406.0100"
    curl -i -sLA "$UA" -b $workdir/cookie -c $workdir/cookie_qy --data "$data" https://m.client.10010.com/mobileService/openPlatform/openPlatLine.htm?to_url=https://qy.chinaunicom.cn/mobile/auth/index >$workdir/qychinaunicom.log
    ticket=$(cat $workdir/qychinaunicom.log | grep -oE "ticket=\w*" | awk -F'[=]' '{print $2}' | head -n1)
    curl -sA "$UA" -b $workdir/cookie_qy -c $workdir/cookie_qy --data "ecsTicket=$ticket" https://qy.chinaunicom.cn/mobile/auth/auth >/dev/null
    
    #签到
    curl -sA "$UA" -b $workdir/cookie_qy "https://qy.chinaunicom.cn/mobile/actsign/queryAccSign?day=$(date +%Y%m)"
    
    #红包雨
    activityId=$(curl -sA "$UA" -b $workdir/cookie_qy https://qy.chinaunicom.cn/mobile-h5/js/redPackageRain/redRain.js | grep -E "var activityId" | grep -oE "[0-9]*")
    sleep $(shuf -i 5-10 -n 1)
    curl -sA "$UA" -b $workdir/cookie_qy "https://qy.chinaunicom.cn/mobile/lottery/doLo?actId=$activityId&score=$(shuf -i 15-50 -n 1)&type="
    
    #小流量博大奖
    actId=$(curl -sA "$UA" -b $workdir/cookie_qy https://qy.chinaunicom.cn/mobile-h5/js/Flow_Purse/slot_machines.js | grep -E "params.actId" | head -n1 | cut -f2 -d"'")
    sleep $(shuf -i 5-10 -n 1)
    curl -sA "$UA" -b $workdir/cookie_qy "https://qy.chinaunicom.cn/mobile/lottery/doLo?enumType=new_turn_l&actId=$actId&level=10"
    
    #猪事顺利
    sleep $(shuf -i 5-10 -n 1)
    curl -sA "$UA" -b $workdir/cookie_qy https://qy.chinaunicom.cn/mobile/lottery/doLo?actId=1000000000121309
    
    #每日一运
    sleep $(shuf -i 5-10 -n 1)
    curl -sA "$UA" -b $workdir/cookie_qy https://qy.chinaunicom.cn/mobile/lottery/doLo?actId=1000000000012802
}

function activeprize() {
Referer1="https://m.client.10010.com/myPrizeForActivity/querywinninglist.htm?pageSign=1&desmobile=$username&version=android@7.0300"
curl -X POST -sA "$UA" -b $workdir/cookie --data "typeScreenCondition=2&category=FFLOWPACKET&pageSign=1&CALLBACKURL=https%3A%2F%2Fm.client.10010.com%2FmyPrizeForActivity%2Fquerywinninglist.htm" -e "$Referer1" https://m.client.10010.com/myPrizeForActivity/mygiftbag.htm > /root/CnUnicom_$username/prizeactive.html
current_dir=$(pwd)
python3 $current_dir/process.py /root/CnUnicom_$username/prizeactive.html
checkfile
Referer2="http://m.client.10010.com/myPrizeForActivity/queryPrizeDetails.htm"
cat /root/CnUnicom_$username/prizeactive.htmlok | while read line
do
activeC=$(echo $line | awk '{print $1}')
prizeID=$(echo $line | awk '{print $2}')
curl -X POST -sA "$UA" -b $workdir/cookie --data "activeCode=$activeC&prizeRecordID=$prizeID&activeName=%E3%80%90%E9%9D%92%E5%B2%9B%E5%95%A4%E9%85%92%E5%9B%9E%E9%A6%88%E7%94%A8%E6%88%B7%E5%A4%A7%E6%8A%BD%E5%A5%96%E3%80%91" -e "$Referer2" https://m.client.10010.com/myPrizeForActivity/myPrize/activationFlowPackages.htm
echo "2分之后执行"
sleep $(shuf -i 130-240 -n 1)
done


}
checkfile(){
if [ ! -f "/root/CnUnicom_$username/prizeactive.htmlok" ];then
sleep 5
checkfile
fi
}



function main() {
    #sleep $(shuf -i 1-10800 -n 1)
    login
    membercenter
    wangzuan
#    login
    club
    activeprize
    #qychinaunicom
    #openChg
    # clean
    rm -rf $workdir
    # exit
    echo; echo $(date) $username Accomplished.  Thanks!
}

main
