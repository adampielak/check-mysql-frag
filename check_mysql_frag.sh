#!/bin/bash
#set -x

# Copyright 2018 Lorenz Wellmer <lorwel@mailbox.org>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This script shows the size difference for innodb_file_per_table files on the disk and the actual data in the tables
# The overhead of heavily fragmented tables can be reduced with optimize table

export MYSQL_PWD=********

MYSQL_USER=root
MYSQL_CONN="-u${MYSQL_USER}"

DBS_INFO=$(mysql ${MYSQL_CONN} -ANe"SHOW DATABASES")

for DB in $DBS_INFO; do
   tbl_loop=0
   if ! [[ $DB =~ ^(information_schema|sys|mysql|performance_schema|"lost+found")$ ]]; then
      TBS_INFO=$(mysql ${MYSQL_CONN} -ANe"SHOW TABLES IN ${DB}")
      for TB in $TBS_INFO; do
         SQL="SELECT data_length+index_length FROM information_schema.tables"
         SQL="${SQL} WHERE table_schema='${DB}' AND table_name='${TB}'"
         TBLSIZE_OPER=$(ls -l /var/lib/mysql/${DB}/${TB}.ibd | awk '{print$5}')
         TBLSIZE_INFO=$(mysql ${MYSQL_CONN} -ANe"${SQL}")
	      TBLSIZE_GB=$(bc -l <<< " $TBLSIZE_INFO / 1073741824 ")
         TBLSIZE_FRAG=$(bc -l <<< " $TBLSIZE_OPER - $TBLSIZE_INFO ")
         TBLSIZE_FRAG_GB=$(bc -l <<< " $TBLSIZE_FRAG / 1073741824 ")
	      TBLSIZE_DIFF_PERC=$(bc -l <<< " ( $TBLSIZE_FRAG / $TBLSIZE_INFO ) * 100 ")
         if [[ $(bc -l <<< "$TBLSIZE_FRAG_GB < 1") == 0 ]]; then
            if [[ $tbl_loop == 0 ]]; then
               printf "Database: $DB\n"
            fi
            printf -- "  Table: $TB\n"
            printf -- "    Actual size:   %.2f GB\n" "$TBLSIZE_GB"
            printf -- "    Fragmentation: %.2f GB\n" "$TBLSIZE_FRAG_GB"
            printf -- "    Percentage:    %.2f %%\n" "$TBLSIZE_DIFF_PERC"
	         ((tbl_loop+=1))
	      fi
      done
   fi
done

