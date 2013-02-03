# -*- coding: utf-8 -*-
require 'pstore'

Plugin.create :favorited_count do
  UserConfig[:global_favedcount] ||= 0
  UserConfig[:notice_devils] ||= true
  UserConfig[:auto_favorite_devils] ||= false
  UserConfig[:auto_favorite_reply_to_me] ||= true
  UserConfig[:auto_favorite_reply_to_other] ||= false
  UserConfig[:auto_favorite_rate_max] ||= 80
  UserConfig[:devilrank_notice_interval] ||= 1000
  UserConfig[:auto_favorite_delay] ||= false
  UserConfig[:auto_favorite_delay_min] ||= 1000
  UserConfig[:auto_favorite_delay_max] ||= 10000
  UserConfig[:auto_favorite_delay_system_message] ||= true

  @@db_tmp_place = "/dev/shm/devils.db"
  @@db_save_place = "/var/tmp/devils.db"

  def db_path
    if File.exist?(@@db_save_place)
      if File.exist?(@@db_tmp_place)
        # tmpもsaveもどちらも存在
        ctime_tmp  = File.ctime(@@db_tmp_place)
        ctime_save = File.ctime(@@db_save_place)
        if ctime_tmp - ctime_save > 0
          # tmpの方が新しい
          `cp #{@@db_tmp_place} #{@@db_save_place}`
        else
          # saveの方が新しい
          `cp #{@@db_save_place} #{@@db_tmp_place}`
        end
      else
        # saveにだけ存在
        `cp #{@@db_save_place} #{@@db_tmp_place}`
      end
    else
      if File.exist?(@@db_tmp_place)
        # tmpにだけ存在
        `cp #{@@db_tmp_place} #{@@db_save_place}`
      else
        # まだ存在してない
      end
    end
    @@db_tmp_place
  end

  @db = PStore.new(db_path)

  def increment(name)
    @db.transaction do
      unless @db.roots
        @db[:devils] = {}
      end

      if @db[:devils][name]
        @db[:devils][name] += 1
      else
        @db[:devils][name] = 1
      end
      
    end
  end

  def devils(name = nil)
    @db.transaction do
      if name
        @db[:devils][name]
      elsif @db[:devils]
        @db[:devils]
      else
        @db[:devils] = {}
      end
    end
  end

  def global_favedcount
    UserConfig[:global_favedcount]
  end

  on_favorite do |service, user, message|
    if user != Service.primary.user
      increment(user.to_s)
      UserConfig[:global_favedcount] += 1
    end

    if UserConfig[:notice_devils]
      if UserConfig[:global_favedcount] % UserConfig[:devilrank_notice_interval] == 0 and UserConfig[:global_favedcount] > 0
        notice_devils(:system => false)
      end
    end

  end

  def notice_devils(hash)
    top = devils.sort_by{|key, value| -value}
    tweet = "現在のふぁぼカウント: #{UserConfig[:global_favedcount]}ふぁぼヾ(★⌒ー⌒★)ノ\n"
    if hash[:system]
      if top.size >= 10
        tweet += "mikutter起動後のふぁぼ魔Top10:\n"
        10.times { |n|
          tweet += "@#{top[n][0]} (#{top[n][1]}ふぁぼ)\n"
        }
      else
        tweet += "mikutter起動後のふぁぼ魔Top#{top.size}:\n"
        top.size.times { |n|
          tweet += "♨#{top[n][0]}(#{top[n][1]}ふぁぼ)\n"
        }
      end
      Plugin.call(:update, nil, [Message.new(:message => tweet, :system => true)])
    else
      if top.size >= 3
        tweet += "mikutter起動後のふぁぼ魔Top3は，♨#{top[0][0]}(#{top[0][1]}ふぁぼ)，♨#{top[1][0]}(#{top[1][1]}ふぁぼ)，♨#{top[2][0]}(#{top[2][1]}ふぁぼ)です！"
      elsif top.size > 0
        tweet += "mikutter起動後のふぁぼ魔Top3は"
        top.size.times { |n|
          tweet += "，♨#{top[n][0]}(#{top[n][1]}ふぁぼ)"
        }
        tweet += "です！"
      end
      Service.primary.post :message => tweet
    end
  end

  def min(rhs, lhs)
    if rhs < lhs
      rhs
    else
      lhs
    end
  end

  def hsv2rgb(hsv)
    h = (hsv[0] / 60.0).floor % 6
    f = hsv[0] / 60.0 - h
    p = hsv[2] * (1 - hsv[1])
    q = hsv[2] * (1 - f * hsv[1])
    t = hsv[2] * (1 - (1 - f) * hsv[1])
    case h
    when 0
      frgb = [ hsv[2], t, p]
    when 1
      frgb = [ q, hsv[2], p]
    when 2
      frgb = [ p, hsv[2], t]
    when 3
      frgb = [ p, q, hsv[2]]
    when 4
      frgb = [ t, p, hsv[2]]
    when 5
      frgb = [ hsv[2], p, q]
    end
    rgb = [ (frgb[0] * 0xffff).floor,
            (frgb[1] * 0xffff).floor,
            (frgb[2] * 0xffff).floor ]
  end

  filter_message_background_color do | mp, array |
    if devils[mp.to_message.user.to_s]
      level = min(1.0, devils[mp.to_message.user.to_s] / 100.0)
      array = hsv2rgb([100 * (1 - level), 0.3, 1.0])
    end
    [mp, array]
  end

  on_appear do |ms|

    if UserConfig[:auto_favorite_reply_to_me] or
        UserConfig[:auto_favorite_devils] or
        UserConfig[:auto_favorite_reply_to_other]

      ms.each do |m|

        if devils[m.message.user.to_s] and m.user != Service.primary.user and not m.retweet?

          # 自分宛のリプライのとき
          if m.message.to_s =~ /@#{Service.primary.user.to_s}/ and UserConfig[:auto_favorite_reply_to_me]
            if rand(100) < min(100, devils[m.to_message.user.to_s]) * UserConfig[:auto_favorite_rate_max] / 100.0
              Thread.new {
                add_favorite m
              }
            end

            # 他人宛のリプライのとき
          elsif m.message.to_s =~ /@[a-zA-Z0-9_]+/ and UserConfig[:auto_favorite_reply_to_other]
            if rand(100) < min(100, devils[m.to_message.user.to_s]) * UserConfig[:auto_favorite_rate_max] / 100.0
              Thread.new {
                add_favorite m
              }
            end

            # リプライじゃないとき
          elsif not m.message.to_s =~ /@[a-zA-Z0-9_]+/ and UserConfig[:auto_favorite_devils]
            if rand(100) < min(100, devils[m.to_message.user.to_s]) * UserConfig[:auto_favorite_rate_max] / 100.0
              Thread.new {
                add_favorite m
              }
            end
          end

        end
      end
    end
  end

  def add_favorite(message)
    delay = add_delay
    unless message.favorite?
      message.favorite
      if UserConfig[:auto_favorite_delay_system_message]
        Plugin.call(:update, nil, [Message.new(:message => "@#{message.user.to_s}のツイートを#{delay}秒の遅延でふぁぼりました", :system => true)])
      end
    end
  end

  def add_delay
    if UserConfig[:auto_favorite_delay]
      delay_min = UserConfig[:auto_favorite_delay_min]
      delay_max = UserConfig[:auto_favorite_delay_max]
      delay_msec = delay_min
      if delay_min < delay_max
        delay_msec += rand(delay_max - delay_min)
      end
      sleep(delay_msec / 1000.0)
      delay_msec / 1000.0
    else
      0
    end      
  end

  settings('ふぁぼ数カウント') do
    settings('ふぁぼ魔ランキング') do
      boolean('ふぁぼ魔ランキング通知を有効にする', :notice_devils).
        tooltip('一定ふぁぼられ数ごとにツイートするよ')
      adjustment('ふぁぼ魔ランキング通知インターバル[ふぁぼられ数]', :devilrank_notice_interval, 20, 10000).
        tooltip('あんまり少ないと大変なことになるよ')
    end
    settings('自動でふぁぼるオプション') do
      boolean('よくふぁぼってくれる人を自動でふぁぼる（リプライを除く）', :auto_favorite_devils)
      boolean('自分宛リプライも自動でふぁぼる', :auto_favorite_reply_to_me)
      boolean('他人宛リプライも自動でふぁぼる', :auto_favorite_reply_to_other)
      adjustment('自動でふぁぼる確率の最大値[%]', :auto_favorite_rate_max, 0, 100).
        tooltip('100%にしちゃう？しちゃう？')
      boolean('遅延ふぁぼを有効にする', :auto_favorite_delay)
      adjustment('遅延ふぁぼ最小値[ミリ秒]', :auto_favorite_delay_min, 0, 20000)
      adjustment('遅延ふぁぼ最大値[ミリ秒]', :auto_favorite_delay_max, 0, 300000)
      boolean('遅延確認のシステムメッセージを有効にする', :auto_favorite_delay_system_message)
    end
  end

  command(:get_favorited_count,
          name: 'こいつからのふぁぼられ数を確認',
          condition: lambda{ |opt| true },
          visible: true,
          role: :timeline) do |opt|
    opt.messages.each { |m|
      count = devils(m.user.to_s)
      count = 0 unless count
      Plugin.call(:update, nil, [Message.new(:message => "@#{m.user.to_s}から#{count}ふぁぼされています", :system => true)])
    }
  end

end
