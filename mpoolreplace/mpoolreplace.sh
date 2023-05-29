#!/bin/bash

### max basefee limit
MaxBasefeeLimitConst=700000000

### max gas premium limit to protect your cost 
MaxGasPremiumLimitConst=600000000

while true
do
    currentBasefee=`lotus chain list --gas-stats --count 1|grep blocks|awk -F'baseFee: ' '{print $2}'|awk '{print $1}'`
    incrBasefee=$currentBasefee
    for i in `lotus mpool pending --local |jq -c "[.Message.From,.Message.Nonce,.Message.GasLimit,(.Message.GasFeeCap|tonumber),(.Message.GasPremium|tonumber),.Message.Method]"`
    do
        from=`echo $i|awk -F, '{print $1}'|awk -F[ '{print $2}'|awk -F\" '{print $2}'`
        nonce=`echo $i |awk -F, '{print $2}'`
        GasLimit=`echo $i|awk -F, '{print $3}'`
        GasFeeCap=`echo $i |awk -F, '{print $4}'`
        GasPremium=`echo $i |awk -F, '{print $5}'`
        Method=`echo $i |awk -F, '{print $6}' |awk -F] '{print $1}'`

        echo $from
        echo $nonce
        echo $GasLimit
        echo $GasFeeCap
        echo $Method

        #### for method 5 (winpost msg ), it should be release as soon as possible.
        if [[ "$Method" == "5" ]];then
            ## change the limit
            echo `date "+%F %T"` "Handling winpost msg"
            let MaxBasefeeLimit=currentBasefee+currentBasefee/2
            
            ## add larger limitation
            let MaxGasPremiumLimit=$((MaxGasPremiumLimitConst*2))
        else
            ## other method , reset to initial setting
            MaxBasefeeLimit=$MaxBasefeeLimitConst
            MaxGasPremiumLimit=$MaxGasPremiumLimitConst
        fi

        if [[ $MaxBasefeeLimit -lt $currentBasefee ]];then
            echo `date "+%F %T"` "checking failed mxBasefeeLimit:$MaxBasefeeLimit,currentBasefee:$currentBasefee"
            break
        fi

        ### feecap 超过当前gas的不需要动
        if [[ $GasFeeCap -gt $currentBasefee ]];then
            echo `date "+%F %T"` "GasFeeCap:$GasFeeCap > currentBasefee:$currentBasefee"
            break
        fi

        ## GasPremium 不能太大
        if [[ $GasPremium -gt $MaxGasPremiumLimit ]];then
            echo `date "+%F %T"` "checking failed GasPremium:$GasPremium > MaxGasPremiumLimit:$MaxGasPremiumLimit" 
            break
        fi
        ## increate 10% 
        let incrBasefee=currentBasefee+currentBasefee/10
        errormsg=`lotus mpool replace --gas-limit=$GasLimit --gas-premium=$GasPremium --gas-feecap=$incrBasefee $from $nonce 2>&1`
            if [[ "$errormsg" != "" ]];then
                    echo $errormsg|grep "replace by fee has too low GasPremium" >>/dev/null
                    if [[ $? -eq 0 ]];then
                            GasPremium=`echo $errormsg|grep -Eo 'to.[0-9]+.from' |awk '{print $2}'`
                            echo `date "+%F %T"` "new GasPremium created: $GasPremium" 
                            echo `date "+%F %T"` "starting replace again........."
                            errormsg=`lotus mpool replace --gas-limit=$GasLimit --gas-premium=$GasPremium --gas-feecap=$incrBasefee $from $nonce 2>&1`
                            echo `date "+%F %T"` "end try....errormsg:$errormsg"
                    fi
            fi
    done ## end for

    ### wait 5 min when check again
    sleep 300
done ## end while
