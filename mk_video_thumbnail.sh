#!/bin/sh
input_dir_path="." # 入力ディレクトリパス
ffmpeg="./ffmpeg"  # ffmpegバイナリパス
find="/bin/find"   # findバイナリパス
tiles_h=8          # サムネイルタイルの水平方向数
tiles_v=8          # サムネイルタイルの垂直方向数
log_file_path="./mk_thumbnail_`date '+%Y%m%d%H%M%S'`.log" # ログファイルパス

# サムネイル作成対象のファイル数の取得
IFS=$'\n';
input_files_cmd='$find $input_dir_path -type f -maxdepth 1 \( -name "*.flv" -o -name "*.mp4" -o -name "*.avi" \)'
nof_files=`eval "$input_files_cmd" | wc -l`
echo "#input files: $nof_files" | tee $log_file_path

counter=1
for file in `eval "$input_files_cmd"`; do
  IFS=$' \t\n'
    
  printf "processing:$file ($counter/$nof_files) is started... " | tee -a $log_file_path
  counter=$(($counter + 1))

  # 既にサムネイルがあるならスキップ
  if [ -e  "${file%.*}_thumb.jpg" ]; then
    printf "already existing.\n" | tee -a $log_file_path
    continue
  fi
  
  # 動画フレーム数の計算（Frames = Duration * FPS）
  hms=(`echo \`$ffmpeg -i "$file" 2>&1 | awk '/Duration/{print $2}' | sed 's/\..*//g' | tr -s ':' ' ' \` `)
  if [ ${#hms[*]} -eq 0 ]; then
    printf "error (duration is not defined).\n" | tee -a $log_file_path
    continue
  fi
  duration_sec=`expr ${hms[0]} \* 3600 + ${hms[1]} \* 60 + ${hms[2]} \* 1`
  src_fps=`$ffmpeg -i "$file" 2>&1 | awk '/fps/{print $0}' | sed 's/\ fps.*//' | sed 's/.*\ //'`
  if [ "$src_fps" = "" ]; then
    printf "error (fps is not defined).\n" | tee -a $log_file_path
    continue
  fi
  frames=`echo "$duration_sec * $src_fps" | bc | sed 's/\..*//g'`

  # サムネイル作成処理
  tiles=$(($tiles_h * $tiles_v))
  thumb_fps=`expr $frames \/ $tiles` 
  if [ $thumb_fps -gt 1000 ]; then 
    thumb_fps=1000
  fi
  $ffmpeg -y -i "$file" -vf thumbnail=${thumb_fps},tile=${tiles_h}x${tiles_v},scale=1920:-1 "${file%.*}_thumb.jpg" >/dev/null 2>&1 | tr -d '\n' | tee -a $log_file_path

  printf "done.\n" | tee -a $log_file_path
done
