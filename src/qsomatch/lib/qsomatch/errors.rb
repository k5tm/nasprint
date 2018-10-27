#!/usr/bin/env ruby
# -*- encoding: utf-8; -*-
#
# Describe errors in comments.
#
require_relative 'crossmatch'

def showMatch(db, id1, timeadj1, id2, timeadj2)
  q1 = lookupQSO(db, id1, timeadj1)
  q2 = lookupQSO(db, id2, timeadj2)
  pm, cp = q1.probablyMatch(q2)
  m = Match.new(q1, q2, pm, cp)
  print m.to_s + "\n"
end

def lookupMult(db, id)
  db.query("select abbrev from Multiplier where id = ? limit 1;", [id]) { |row|
    return row[0]
  }
  nil
end

def fillInComment(db, contestID)
  db.query("select q1.id, q1.band, q1.fixedMode, q1.time, l1.clockadj, c1.basecall, q1.recvd_serial, qe1.recvd_location, q1.recvd_multiplierID, q2.band, q2.fixedMode, q2.time, l2.clockadj, c2.basecall, q2.sent_serial, qe2.sent_location, q1.judged_multiplierID, q1.matchID, l1.trustedclock, l2.trustedclock from QSO as q1 join QSOExtra as qe1 on q1.id = qe1.id, QSO as q2 join QSOExtra as qe2 on q2.id = qe2.id, Callsign as c1, Callsign as c2, Log as l1, Log as l2 where q1.logID = l1.id  and q2.logID = l2.id and l1.contestID = ? and l2.contestID = ? and (q1.matchType in ('Partial','PartialBye') or (q1.matchType = 'Full' and q1.score < 2)) and q1.matchID is not null and q2.id = q1.matchID and q1.id = q2.matchID and qe1.comment is null and c1.id = q1.recvd_callID and c2.id = q2.sent_callID;",
           [contestID, contestID]) { |row|
    comments = Array.new
    if row[5] != row[13]
      comments << "busted call #{row[13]}"
    end
    if row[1] != row[9]
      comments << "band mismatch #{row[9]}"
    end
    if row[2] != row[10]
      comments << "mode mismatch #{row[10]}"
    end
    if ((db.toDateTime(row[3]) + row[4]) - 
        (db.toDateTime(row[11]) + row[12])).abs > CrossMatch::PERFECT_TIME_MATCH*60 and
        db.toBool(row[19]) or not db.toBool(row[18])
      comments << "time mismatch #{(db.toDateTime(row[11])+row[12]).to_s}"
    end
    if (row[6].to_i - row[14].to_i).abs > 1
      comments << "serial # #{row[14]}"
    end
    if not row[8] or (row[8] != row[16])
      comments << "location mismatch #{lookupMult(db,row[16])}"
    end
    if comments.empty?
      print "Looks like a full match was missed #{row[0]} #{row[4]} #{row[12]}\n"
      showMatch(db, row[0], row[4], row[17], row[12])
    else
      db.query("update QSOExtra set comment=? where id = ? limit 1;",
               [comments.join(", "), row[0]]) { }
    end
  }
  db.query("select q.id, e.name, e.continent from QSO as q join Multiplier as m on (q.recvd_multiplierID = m.id and m.abbrev = 'DX') join Entity as e on e.id = q.recvd_entityID where q.matchType in ('Full', 'Bye');") { |row|
    db.query("update QSOExtra set comment = ('DX=' + ? + ' (' + ? + ')') where id = ? limit 1;",
             [row[1].to_s, row[2].to_s, row[0].to_i]) { }
  }
end
  
