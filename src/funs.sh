#! /usr/bin/env bash

FUNS_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")


# Count reads and normalize
intersect_reads() {
    local reads="$1"
    local region="$2"
    local threads="$3"
    local out="$4"
    local out_N="$5"
    local flags=$6

    local tmp_dir=$(dirname "$out")
    local tmp_1=$(mktemp -p $tmp_dir tmp_bed.XXXXX)
    local tmp_2=$(mktemp -p $tmp_dir tmp_bed.XXXXX)

    zcat "$reads" \
        > $tmp_1

    cat $tmp_1 \
        | bedtools intersect -sorted -a "$region" -b - $flags \
        | sort -S1G --parallel="$threads" -k1,1 -k2,2n \
        > $tmp_2

    "$FUNS_DIR/norm_bed" $tmp_1 $tmp_2 7 -len \
        | sort -S1G --parallel="$threads" -k1,1 -k2,2n \
        | pigz -p "$threads" \
        > "$out_N"

    cat $tmp_2 \
        | pigz -p "$threads" \
        > "$out"

    rm $tmp_1 $tmp_2
}


# Create bigwigs
create_bigwig() {
    local reads="$1"
    local strand="$2"
    local mtplyr="$3"
    local bg="$4"
    local bg_N="$5"
    local bw="$6"
    local chroms="$7"
    local threads="$8"

    tmp_1=$(mktemp tmp.XXXXX)
    tmp_2=$(mktemp tmp.XXXXX)
    tmp_3=$(mktemp tmp.XXXXX)

    zcat -f "$reads" \
        > $tmp_1

    cat $tmp_1 \
        | sort -S1G --parallel="$threads" -k1,1 -k2,2n \
        | bedtools genomecov -bg $strand -i - -g "$chroms" \
        > $tmp_2

    $FUNS_DIR/norm_bed $tmp_1 $tmp_2 4 \
        | sort -S1G --parallel="$threads" -k1,1 -k2,2n \
        | awk -v mtplyr="$mtplyr" -v OFS="\t" '{$4 = $4 * mtplyr; print}' \
        > $tmp_3
    
    bedGraphToBigWig \
        $tmp_3 \
        "$chroms" \
        "$bw"

    cat $tmp_2 \
        | pigz -p "$threads" \
        > "$bg"

    cat $tmp_3 \
        | pigz -p "$threads" \
        > "$bg_N"

    rm $tmp_1 $tmp_2 $tmp_3
}


# Write URLs
create_urls() {
    local paths=$1
    local ssh="$2"
    local url="$3"
    local url_file="$4"
    local grp_re="${5:-}"

    local header="URL\tSAMPLE\tSTRAND"
    local cmd='echo -e $url\t$sam\t$strand'

    if [ ! -z "$grp_re" ]
    then
        local header="${header/STRAND/GROUP\\tSTRAND}"
        local cmd="${cmd/strand/grp\\t\$strand}"
    fi

    if [ ! -s "$url_file" ]
    then
        echo -e "$header" \
            > "$url_file"
    fi

    for path in $paths
    do
        local bw=$(basename "$path")
        local url="$url/$bw"
        local strand=$(echo "$bw" | grep -oP "(?<=_)[a-zA-Z]+(?=.bw)")
        local sffx="$strand"
        
        if [ ! -z "$grp_re" ]
        then
            local grp=$(echo "$bw" | grep -oP "(?<=-)""$grp_re""(?=_"$strand".bw$)")
            local sffx="$grp"
        fi
        
        local sam=$(echo "$bw" | grep -oP ".+(?=[_-])""$sffx")

        rsync -e 'ssh -o StrictHostKeyChecking=no' --perms --chmod=ugo+r "$path" "$ssh"

        eval "$cmd" \
            >> "$url_file"
    done
}


