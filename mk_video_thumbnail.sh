#!/bin/sh

input_dir_path="."															# 入力ディレクトリパス
output_dir_path="${input_dir_path}/thumbs/"									# 出力ディレクトリパス
log_file_path="${output_dir_path}/mk_thumbnail_`date '+%Y%m%d%H%M%S'`.log"	# ログファイルパス

ffmpeg="/bin/ffmpeg"	# ffmpegバイナリパス
find="/bin/find"	# findバイナリパス

tiles_h=8			# サムネイルタイルの水平方向数
tiles_v=8			# サムネイルタイルの垂直方向数

# 出力ディレクトリ生成
if [ ! -e "$output_dir_path" ]; then
	mkdir -p "$output_dir_path"
fi

# サムネイル作成対象のファイル数の取得
IFS=$'\n';
input_files_cmd='$find $input_dir_path -maxdepth 1 -type f \( -name "*.flv" -o -name "*.mp4" -o -name "*.avi" -o -name "*.ts" -o -name "*.wmv" \)'
nof_files=`eval "$input_files_cmd" | wc -l`
echo "#input files: $nof_files" | tee $log_file_path

counter=1
for file in `eval "$input_files_cmd"`; do
	IFS=$' \t\n'
		
	printf "processing:$file ($counter/$nof_files) is started... " | tee -a $log_file_path
	counter=$(($counter + 1))

	# 既にサムネイルがあるならスキップ
	input_filename="${file##*/}"
	output_filepath="${output_dir_path}${input_filename%.*}_thumb.jpg"
	if [ -e	"$output_filepath" ]; then
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
	ffmpeg_msg=`$ffmpeg -y -i "$file" -vf thumbnail=${thumb_fps},tile=${tiles_h}x${tiles_v},scale=1920:-1 "$output_filepath" \
		2>&1 > /dev/null | grep -E 'error|failed' | tr -d '\n'`
	if [ "$ffmpeg_msg" = "" ]; then
		printf "succeeded.\n" | tee -a $log_file_path
	else
		printf "error (ffmpeg:$ffmpeg_msg)\n" | tee -a $log_file_path
	fi
done
printf "making thumbnail is done !!\n\n"
printf "================================================================================\n\n"

# 出力ディレクトリにおけるサムネイルについて，対応するソースの動画が存在しないなら，サムネイルを削除
echo "checking existing thumbnails."
IFS=$'\n';
input_files_cmd='$find $output_dir_path -maxdepth 1 -mindepth 1 -regex ".*_thumb\.jpg$"'
nof_files=`eval "$input_files_cmd" | wc -l`
echo "#thumbnail files: $nof_files" | tee -a $log_file_path

counter=1
for file in `eval "$input_files_cmd"`; do
	counter=$(($counter + 1))
	video_file_name=`echo $file | sed 's/.*\/\([^\/]*\)_thumb\.jpg/\1/' | sed 's/\(\[\|\]\|\*\|\?\)/\\\\\1/g'`
	find_video_cmd_result=`$find $input_dir_path -maxdepth 1 -mindepth 1 -name "${video_file_name}.*"`
	if [ "" = "$find_video_cmd_result" ]; then
		rm -f "$file"
		printf "source video file of thumbnail:${file} is missing. therefore, this thumbnail is removed.\n" | tee -a $log_file_path
	fi
done
printf "complete !!"
