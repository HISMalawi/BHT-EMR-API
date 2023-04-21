# frozen_string_literal: true

module ANCService
    class PatientVisitLabel
      attr_accessor :patient, :date

      PROGRAM = Program.find_by name: "ANC PROGRAM"

      def initialize(patient, date)
        @patient = patient
        @date = date
      end

      def print
        self.print1 + self.print2 + self.detailed_obstetric_history_label
      end

      def print1
        visit = ANCService::PatientVisit.new patient, date
        return unless visit

        @current_range = visit.active_range(@date.to_date)

        encounters = {}

        @patient.encounters.where(["encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?",
          @current_range[0]["START"], @current_range[0]["END"], PROGRAM.id]).collect{|e|
          encounters[e.encounter_datetime.strftime("%d/%b/%Y")] = {"USER" => PersonName.find_by(person_id: e.provider_id) }
        }

        @patient.encounters.where(["encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?",
          @current_range[0]["START"], @current_range[0]["END"], PROGRAM.id]).collect{|e|
          encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase] = ({} rescue "") if !e.type.nil?
        }

        @patient.encounters.where(["encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?",
          @current_range[0]["START"], @current_range[0]["END"], PROGRAM.id]).collect{|e|
            if !e.type.nil?
              e.observations.each{|o|
                concept = ConceptName.find_by concept_id: o.concept_id
                value = getObsValue(o)
                if !concept.name.blank?
                  if concept.name.upcase == "DIAGNOSIS" && encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][concept.name.upcase]
                    encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][concept.name.upcase] += "; " + value
                  else
                    encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][concept.name.upcase] = value
                    if concept.name.upcase == "PLANNED DELIVERY PLACE"
                      @current_range[0]["PLANNED DELIVERY PLACE"] = value
                    elsif concept.name.upcase == "MOSQUITO NET"
                      @current_range[0]["MOSQUITO NET"] = value
                    end
                  end
                end
              } #rescue nil
            end
          }

          @drugs = {};
          @other_drugs = {};
          main_drugs = ["TD", "SP", "Fefol", "Albendazole"]

          @patient.encounters.where(["(encounter_type = ? OR encounter_type = ?) AND encounter_datetime >= ? AND encounter_datetime <= ?",
              EncounterType.find_by_name("TREATMENT").id, EncounterType.find_by_name("DISPENSING").id,
              @current_range[0]["START"], @current_range[0]["END"]]).order("encounter_datetime DESC").each{|e|
            @drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@drugs[e.encounter_datetime.strftime("%d/%b/%Y")];
            @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")];
            e.orders.each{|o|

              drug_name = o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i) ?
                (o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")].to_s + " " +
                  o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)[0]) :
                (o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]) rescue o.drug_order.drug.name

              if ((main_drugs.include?(o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")])) rescue false)

                @drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0,
                    o.drug_order.drug.name.index(" ")]] = o.drug_order.quantity #amount_needed
              else

                @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")][drug_name] = o.drug_order.quantity #amount_needed
              end
            }
          }

          label = ZebraPrinter::StandardLabel.new

          label.draw_line(20,25,800,2,0)
          label.draw_line(20,25,2,280,0)
          label.draw_line(20,305,800,2,0)
          label.draw_line(805,25,2,280,0)
          label.draw_text("Visit Summary",40,33,0,1,1,2,false)
          label.draw_text("Last Menstrual Period: #{@current_range[0]["START"].to_date.strftime("%d/%b/%Y") rescue ""}",40,76,0,2,1,1,false)
          label.draw_text("Expected Date of Delivery: #{(@current_range[0]["END"].to_date).strftime("%d/%b/%Y") rescue ""}",40,99,0,2,1,1,false)
          label.draw_line(28,60,132,1,0)
          label.draw_line(20,130,800,2,0)
          label.draw_line(20,190,800,2,0)
          label.draw_text("Gest.",41,140,0,2,1,1,false)
          label.draw_text("Fundal",99,140,0,2,1,1,false)
          label.draw_text("Pos./",178,140,0,2,1,1,false)
          label.draw_text("Fetal",259,140,0,2,1,1,false)
          label.draw_text("Weight",339,140,0,2,1,1,false)
          label.draw_text("(kg)",339,158,0,2,1,1,false)
          label.draw_text("BP",435,140,0,2,1,1,false)
          label.draw_text("Urine",499,138,0,2,1,1,false)
          label.draw_text("Prote-",499,156,0,2,1,1,false)
          label.draw_text("in",505,174,0,2,1,1,false)
          label.draw_text("SP",595,140,0,2,1,1,false)
          label.draw_text("(tabs)",575,158,0,2,1,1,false)
          label.draw_text("FeFo",664,140,0,2,1,1,false)
          label.draw_text("(tabs)",655,158,0,2,1,1,false)
          label.draw_text("Albe.",740,140,0,2,1,1,false)
          label.draw_text("(tabs)",740,156,0,2,1,1,false)
          label.draw_text("Age",41,158,0,2,1,1,false)
          label.draw_text("Height",99,158,0,2,1,1,false)
          label.draw_text("Pres.",178,158,0,2,1,1,false)
          label.draw_text("Heart",259,158,0,2,1,1,false)
          label.draw_line(90,130,2,175,0)
          label.draw_line(170,130,2,175,0)
          label.draw_line(250,130,2,175,0)
          label.draw_line(330,130,2,175,0)
          label.draw_line(410,130,2,175,0)
          label.draw_line(490,130,2,175,0)
          label.draw_line(570,130,2,175,0)
          label.draw_line(650,130,2,175,0)
          label.draw_line(730,130,2,175,0)

          @i = 0

          out = []

          #raise encounters.inspect

          encounters.each{|v,k|
            out << [k["ANC VISIT TYPE"]["REASON FOR VISIT"].to_i, v] rescue []
          }
          out = out.sort.compact

          # raise out.to_yaml

          out.each do |key, element|

            encounter = encounters[element]

            @i = @i + 1

            if element == @date.to_date.strftime("%d/%b/%Y")
              visit = encounters[element]["ANC VISIT TYPE"]["REASON FOR VISIT"].to_i

              label.draw_text("Visit No: #{visit}",250,33,0,1,1,2,false)
              label.draw_text("Visit Date: #{element}",450,33,0,1,1,2,false)

              fundal_height = encounters[element]["ANC EXAMINATION"]["FUNDUS"].to_i rescue 0

              gestation_weeks = getEquivFundalWeeks(fundal_height) rescue "";

              gest = gestation_weeks.to_s

              label.draw_text(gest,41,200,0,2,1,1,false)

              label.draw_text("wks",41,226,0,2,1,1,false)

              fund = (fundal_height <= 0 ? "?" : fundal_height.to_s + "(cm)") rescue ""

              label.draw_text(fund,99,200,0,2,1,1,false)

              posi = encounters[element]["ANC EXAMINATION"]["POSITION"] rescue ""
              pres = encounters[element]["ANC EXAMINATION"]["PRESENTATION"] rescue ""

              posipres = paragraphate(posi.to_s + pres.to_s,5, 5)

              (0..(posipres.length)).each{|u|
                label.draw_text(posipres[u].to_s,178,(200 + (13 * u)),0,2,1,1,false)
              }

              fet = (encounters[element]["ANC EXAMINATION"]["FETAL HEART BEAT"].humanize == "Unknown" ? "?" :
                  encounters[element]["ANC EXAMINATION"]["FETAL HEART BEAT"].humanize).gsub(/Fetal\smovement\sfelt\s\(fmf\)/i,"FMF") rescue ""

              fet = paragraphate(fet, 5, 5)

              (0..(fet.length)).each{|f|
                label.draw_text(fet[f].to_s,259,(200 + (13 * f)),0,2,1,1,false)
              }

              wei = (encounters[element]["VITALS"]["WEIGHT (KG)"].to_i <= 0 ? "?" :
                  ((encounters[element]["VITALS"]["WEIGHT (KG)"].to_s.match(/\.[1-9]/) ?
                      encounters[element]["VITALS"]["WEIGHT (KG)"] :
                      encounters[element]["VITALS"]["WEIGHT (KG)"].to_i))) rescue ""

              label.draw_text(wei.to_s,339,200,0,2,1,1,false)

              sbp = (encounters[element]["VITALS"]["SYSTOLIC BLOOD PRESSURE"].to_i <= 0 ? "?" :
                  encounters[element]["VITALS"]["SYSTOLIC BLOOD PRESSURE"].to_i) rescue "?"

              dbp = (encounters[element]["VITALS"]["DIASTOLIC BLOOD PRESSURE"].to_i <= 0 ? "?" :
                  encounters[element]["VITALS"]["DIASTOLIC BLOOD PRESSURE"].to_i) rescue "?"

              bp = paragraphate(sbp.to_s + "/" + dbp.to_s, 4, 3)

              (0..(bp.length)).each{|u|
                label.draw_text(bp[u].to_s,420,(200 + (18 * u)),0,2,1,1,false)
              }

              uri = encounters[element]["LAB RESULTS"]["URINE PROTEIN"] rescue ""

              uri = paragraphate(uri, 5, 5)

              (0..(uri.length)).each{|u|
                label.draw_text(uri[u].to_s,498,(200 + (18 * u)),0,2,1,1,false)
              }

              sp = (@drugs[element]["SP"].to_i > 0 ? @drugs[element]["SP"].to_i : "") rescue ""

              label.draw_text(sp,595,200,0,2,1,1,false)

              @ferrous_fefol =  @other_drugs.keys.collect{|date|
                @other_drugs[date].keys.collect{|key|
                  @other_drugs[date][key] if ((@other_drugs[date][key].to_i > 0 and key.downcase.strip == "ferrous") rescue false)
                }
              }.compact.first.to_s rescue ""

              fefo = (@drugs[element]["Fefol"].to_i > 0 ? @drugs[element]["Fefol"].to_i : "") rescue ""

              fefo = (fefo.to_i + @ferrous_fefol.to_i) rescue fefo
              fefo = "" if (fefo.to_i == 0 rescue false)

              label.draw_text(fefo.to_s,664,200,0,2,1,1,false)

              albe = (@drugs[element]["Albendazole"].to_i > 0 ? @drugs[element]["Albendazole"].to_i : "") rescue ""

              label.draw_text(albe.to_s,740,200,0,2,1,1,false)
            end

          end

          @encounters = encounters

          label.print(1)
        end

        def print2
          visit = ANCService::PatientVisit.new patient, date
          return unless visit

          @current_range = visit.active_range(@date.to_date)

          # raise @current_range.to_yaml

          encounters = {}

          @patient.encounters.where(["encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?",
              @current_range[0]["START"], @current_range[0]["END"], PROGRAM.id]).collect{|e|
            encounters[e.encounter_datetime.strftime("%d/%b/%Y")] = {"USER" => PersonName.find_by(person_id: e.provider_id) }
          }

          @patient.encounters.where(["encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?",
              @current_range[0]["START"], @current_range[0]["END"], PROGRAM.id]).collect{|e|
            encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase] = ({} rescue "") if !e.type.nil?
          }

          @patient.encounters.where(["encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?",
              @current_range[0]["START"], @current_range[0]["END"], PROGRAM.id]).collect{|e|
            e.observations.each{|o|
              concept = ConceptName.find_by concept_id: o.concept_id rescue nil
              value = getObsValue(o)
              if !concept.blank?
                if concept.name.upcase == "DIAGNOSIS" && encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][concept.name.upcase]
                  encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][concept.name.upcase] += "; " + value
                else
                  encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][concept.name.upcase] = (value rescue "") if !e.type.nil?
                  if concept.name.upcase == "PLANNED DELIVERY PLACE"
                    @current_range[0]["PLANNED DELIVERY PLACE"] = value
                  elsif concept.name.upcase == "MOSQUITO NET"
                    @current_range[0]["MOSQUITO NET"] = value
                  end
                end
              end
            } #rescue nil
          }

          @drugs = {};
          @other_drugs = {};
          main_drugs = ["TD", "SP", "Fefol", "Albendazole"]

          @patient.encounters.where(["(encounter_type = ? OR encounter_type = ?) AND encounter_datetime >= ? AND encounter_datetime <= ?
            AND program_id = ?",EncounterType.find_by_name("TREATMENT").id, EncounterType.find_by_name("DISPENSING").id,
              @current_range[0]["START"], @current_range[0]["END"], PROGRAM.id]).order("encounter_datetime DESC").each{|e|
            @drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@drugs[e.encounter_datetime.strftime("%d/%b/%Y")];
            @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")];
            e.orders.each{|o|

              drug_name = o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i) ?
                (o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")] + " " +
                  o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)[0]) :
                (o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]) rescue o.drug_order.drug.name

              main_drugs_passed = ((main_drugs.include?(o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]))) rescue false

              if main_drugs_passed
                @drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0,
                    o.drug_order.drug.name.index(" ")]] = o.drug_order.quantity
              else

                @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")][drug_name] = o.drug_order.quantity #amount_needed
              end
            }
          }

          label = ZebraPrinter::StandardLabel.new

          label.draw_line(20,25,800,2,0)
          label.draw_line(20,25,2,280,0)
          label.draw_line(20,305,800,2,0)
          label.draw_line(805,25,2,280,0)

          label.draw_line(20,130,800,2,0)
          label.draw_line(20,190,800,2,0)

          label.draw_line(160,130,2,175,0)
          label.draw_line(364,130,2,175,0)
          label.draw_line(594,130,2,175,0)
          label.draw_line(706,130,2,175,0)
          label.draw_text("Planned Delivery Place: #{@current_range[0]["PLANNED DELIVERY PLACE"] rescue ""}",40,66,0,2,1,1,false)
          label.draw_text("Bed Net Given: #{@current_range[0]["MOSQUITO NET"] rescue ""}",40,99,0,2,1,1,false)
          label.draw_text("",28,138,0,2,1,1,false)
          label.draw_text("TD",75,156,0,2,1,1,false)

          label.draw_text("Diagnosis",170,140,0,2,1,1,false)
          label.draw_text("Medication/Outcome",370,140,0,2,1,1,false)
          label.draw_text("Next Vis.",600,140,0,2,1,1,false)
          label.draw_text("Date",622,158,0,2,1,1,false)
          label.draw_text("Provider",710,140,0,2,1,1,false)

          @i = 0

          out = []

          encounters.each{|v,k|
            out << [k["ANC VISIT TYPE"]["REASON FOR VISIT"].to_i, v] rescue []
          }
          out = out.sort.compact

          # raise out.to_yaml

          out.each do |key, element|

            encounter = encounters[element]
            @i = @i + 1

            if element == @date.to_date.strftime("%d/%b/%Y")

              td = (@drugs[element]["TD"] > 0 ? 1 : "") rescue ""

              label.draw_text(td.to_s,28,200,0,2,1,1,false)

              sign = "";
              diagnosis = ["malaria", "anaemia", "pre-eclampsia", "vaginal bleeding", "early rupture of membranes",
                "premature labour","pneumonia", "verruca planus, extensive"]

              anc_exam = encounter["ANC EXAMINATION"]

              unless anc_exam.blank?
                  anc_exam.each do |key, value|
                  if diagnosis.include?(key.downcase)
                    sign += "#{key.downcase}, "
                  end
                end
              end

              sign = paragraphate(sign.to_s, 13, 5)

              (0..(sign.length)).each{|m|
                label.draw_text(sign[m].to_s,175,(200 + (25 * m)),0,2,1,1,false)
              }

              med = encounters[element]["UPDATE OUTCOME"]["OUTCOME"].humanize + "; " rescue ""
              oth = (@other_drugs[element].collect{|d, v|
                  "#{d}: #{ (v.to_s.match(/\.[1-9]/) ? v : v.to_i) }"
                }.join("; ")) if @other_drugs[element].length > 0 rescue ""

              med = paragraphate(med.to_s + oth.to_s, 17, 5)

              (0..(med.length)).each{|m|
                label.draw_text(med[m].to_s,370,(200 + (18 * m)),0,2,1,1,false)
              }
              nex = encounters[element]["APPOINTMENT"]["APPOINTMENT DATE"] rescue []

              if nex != []
                date = nex.to_date
                nex = []
                nex << date.strftime("%d/")
                nex << date.strftime("%b/")
                nex << date.strftime("%Y")
              end

              (0..(nex.length)).each{|m|
                label.draw_text(nex[m].to_s,610,(200 + (18 * m)),0,2,1,1,false)
              }

              user = "#{encounters[element]["USER"].given_name[0].upcase}.#{encounters[element]["USER"].family_name[0].upcase}" rescue ""

              use = user #(encounters[element]["USER"].split(" ") rescue []).collect{|n| n[0,1].upcase + "."}.join("")  rescue ""

              # use = paragraphate(use.to_s, 5, 5)

              # (0..(use.length)).each{|m|
              #   label.draw_text(use[m],710,(200 + (18 * m)),0,2,1,1,false)
              # }

              label.draw_text(use.to_s,730,200,0,2,1,1,false)

            end
          end

          label.print(1)
      end

      def active_range(date = Date.today)

        current_range = {}

        active_date = date

        pregnancies = {};

      # active_years = {}

        abortion_check_encounter = self.patient.encounters.where(["encounter_type = ? AND encounter_datetime > ? AND DATE(encounter_datetime) <= ?",
            EncounterType.find_by_name("PREGNANCY STATUS").encounter_type_id, date.to_date - 7.months, date.to_date]).order(["encounter_datetime DESC"]).first rescue nil

        aborted = abortion_check_encounter.observations.collect{|ob| ob.answer_string.downcase.strip if ob.concept_id == ConceptName.find_by_name("PREGNANCY ABORTED").concept_id}.compact.include?("yes")  rescue false

        date_aborted = abortion_check_encounter.observations.find_by_concept_id(ConceptName.find_by_name("DATE OF SURGERY").concept_id).answer_string rescue nil
        recent_lmp = self.find_by_sql(["SELECT * from obs WHERE person_id = #{self.patient.id} AND concept_id =
                            (SELECT concept_id FROM concept_name WHERE name = 'DATE OF LAST MENSTRUAL PERIOD' LIMIT 1)"]).last.answer_string.squish.to_date rescue nil

        self.patient.encounters.order(["encounter_datetime DESC"]).each{|e|
          if e.name == "CURRENT PREGNANCY" && !pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")]
            pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")] = {}

            e.observations.each{|o|
              concept = o.concept.name rescue nil
              if concept
                # if !active_years[e.encounter_datetime.beginning_of_quarter.strftime("%Y-%m-%d")]
                if o.concept_id == (ConceptName.find_by_name("DATE OF LAST MENSTRUAL PERIOD").concept_id rescue nil)
                  pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")]["DATE OF LAST MENSTRUAL PERIOD"] = o.answer_string.squish
                  # active_years[e.encounter_datetime.beginning_of_quarter.strftime("%Y-%m-%d")] = true
                end
                # end
              end
            }
          end
        }

        # pregnancies = pregnancies.delete_if{|x, v| v == {}}

        pregnancies.each{|preg|
          if preg[1]["DATE OF LAST MENSTRUAL PERIOD"]
            preg[1]["START"] = preg[1]["DATE OF LAST MENSTRUAL PERIOD"].to_date
            preg[1]["END"] = preg[1]["DATE OF LAST MENSTRUAL PERIOD"].to_date + 7.day + 45.week # 9.month
          else
            preg[1]["START"] = preg[0].to_date
            preg[1]["END"] = preg[0].to_date + 7.day + 45.week # 9.month
          end

          if active_date >= preg[1]["START"] && active_date <= preg[1]["END"]
            current_range["START"] = preg[1]["START"]
            current_range["END"] = preg[1]["END"]
          end
        }

        if recent_lmp.present?
          current_range["START"] = recent_lmp
          current_range["END"] = current_range["START"] + 9.months
        end

        if (abortion_check_encounter.present? && aborted && date_aborted.present? && current_range["START"].to_date < date_aborted.to_date rescue false)

          current_range["START"] = date_aborted.to_date + 10.days
          current_range["END"] = current_range["START"] + 9.months
        end

        current_range["END"] = current_range["START"] + 7.day + 45.week unless ((current_range["START"]).to_date.blank? rescue true)

        return [current_range, pregnancies]
    end

    def truncate(string, length = 6)
      string[0,length] + "."
    end

    def detailed_obstetric_history_label(date = Date.today)
      @patient = self.patient rescue nil

      @obstetrics = {}
      search_set = ["YEAR OF BIRTH", "PLACE OF BIRTH", "BIRTHPLACE", "PREGNANCY", "GESTATION", "LABOUR DURATION",
        "METHOD OF DELIVERY", "CONDITION AT BIRTH", "BIRTH WEIGHT", "ALIVE",
        "AGE AT DEATH", "UNITS OF AGE OF CHILD", "PROCEDURE DONE"]
      current_level = 0

      @new_encounter = @patient.encounters.joins([:observations]).where(["encounter_type = ? AND comments regexp 'p'",
          EncounterType.find_by_name("OBSTETRIC HISTORY")]).last

      if @new_encounter.blank?
        Encounter.where(["encounter_type = ? AND patient_id = ?",
            EncounterType.find_by_name("OBSTETRIC HISTORY").id, @patient.id]).order(["encounter_datetime ASC"]).each{|e|
          e.observations.each{|obs|
            concept = obs.concept.concept_names.map(& :name).last rescue nil
            if(!concept.nil?)
              if search_set.include?(concept.upcase)
                if obs.concept_id == (ConceptName.find_by_name("YEAR OF BIRTH").concept_id rescue nil)
                  current_level += 1

                  @obstetrics[current_level] = {}
                end

                if @obstetrics[current_level]
                  @obstetrics[current_level][concept.upcase] = obs.answer_string rescue nil

                  if obs.concept_id == (ConceptName.find_by_name("YEAR OF BIRTH").concept_id rescue nil) && obs.answer_string.to_i == 0
                    @obstetrics[current_level]["YEAR OF BIRTH"] = "Unknown"
                  end
                end

              end
            end
          }
        }
      else

        @data = {}
        @new_encounter.observations.each do |obs|


          next if !(obs.comments || "").match(/p/i)
          p = obs.comments.match(/p\d+/i)[0].match(/\d+/)[0]
          n = obs.comments.match(/b\d+/i)[0].match(/\d+/)[0]
          @data[p] = {} if @data[p].blank?
          @data[p][n] = {} if @data[p][n].blank?
          concept = obs.concept.concept_names.map(& :name).last rescue nil
          @data[p][n][concept.upcase.strip] = obs.answer_string
        end

        current_level = 1
        @data.keys.sort.each do |prg|

          @data[prg].keys.sort.each do |key|

            @obstetrics[current_level] = @data[prg][key]
            current_level += 1
          end
        end
      end

      #grab units of age of child
      unit = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('UNITS OF AGE OF CHILD').concept_id]).last.answer_string.squish rescue nil


      # raise @anc_patient.to_yaml

      @pregnancies = self.active_range

      @range = []

      @pregnancies = @pregnancies[1]

      @pregnancies.each{|preg|
        @range << preg[0].to_date
      }

      @range = @range.sort

      @range.each{|y|
        current_level += 1
        @obstetrics[current_level] = {}
        @obstetrics[current_level]["YEAR OF BIRTH"] = y.year
        @obstetrics[current_level]["PLACE OF BIRTH"] = "<b>(Here)</b>"
      }

      label = ZebraPrinter::StandardLabel.new
      label2 = ZebraPrinter::StandardLabel.new
      label2set = false
      label3 = ZebraPrinter::StandardLabel.new
      label3set = false

      label.draw_text("Detailed Obstetric History",28,29,0,1,1,2,false)
      label.draw_text("Pr.",35,65,0,2,1,1,false)
      label.draw_text("No.",35,85,0,2,1,1,false)
      label.draw_text("Year",59,65,0,2,1,1,false)
      label.draw_text("Place",110,65,0,2,1,1,false)
      label.draw_text("Gest.",225,65,0,2,1,1,false)
      label.draw_text("months",223,85,0,2,1,1,false)
      #label.draw_text("Labour",305,65,0,2,1,1,false)
      #label.draw_text("durat.",305,85,0,2,1,1,false)
      #label.draw_text("(hrs)",310,105,0,2,1,1,false)
      label.draw_text("Delivery",310,65,0,2,1,1,false)
      label.draw_text("Method",310,85,0,2,1,1,false)
      label.draw_text("Condition",430,65,0,2,1,1,false)
      label.draw_text("at birth",430,85,0,2,1,1,false)
      label.draw_text("Birth",552,65,0,2,1,1,false)
      label.draw_text("weight",547,85,0,2,1,1,false)
      label.draw_text("(kg)",550,105,0,2,1,1,false)
      label.draw_text("Alive.",643,65,0,2,1,1,false)
      label.draw_text("now?",645,85,0,2,1,1,false)
      label.draw_text("Age at",715,65,0,2,1,1,false)
      label.draw_text("death*",715,85,0,2,1,1,false)
      label.draw_text("(" + unit[0..2] + ".)", 745,105,0,2,1,1,false) if unit



      label.draw_line(20,60,800,2,0)
      label.draw_line(20,60,2,245,0)
      label.draw_line(20,305,800,2,0)
      label.draw_line(805,60,2,245,0)
      label.draw_line(20,125,800,2,0)

      label.draw_line(56,60,2,245,0)
      label.draw_line(105,60,2,245,0)
      label.draw_line(220,60,2,245,0)
      label.draw_line(295,60,2,245,0)
      #label.draw_line(380,60,2,245,0)
      label.draw_line(415,60,2,245,0)
      label.draw_line(535,60,2,245,0)
      label.draw_line(643,60,2,245,0)
      label.draw_line(700,60,2,245,0)

      (1..(@obstetrics.length + 1)).each do |pos|

        @place = (@obstetrics[pos] ? (@obstetrics[pos]["BIRTHPLACE"] ?
              @obstetrics[pos]["BIRTHPLACE"] : "") : "").gsub(/Centre/i,
          "C.").gsub(/Health/i, "H.").gsub(/Center/i, "C.")

        @gest = (@obstetrics[pos] ? (@obstetrics[pos]["GESTATION"] ?
              @obstetrics[pos]["GESTATION"] : "") : "")

        @gest = (@gest.length > 5 ? truncate(@gest, 5) : @gest)

        @delmode = (@obstetrics[pos] ? (@obstetrics[pos]["METHOD OF DELIVERY"] ?
              @obstetrics[pos]["METHOD OF DELIVERY"].titleize : (@obstetrics[pos]["PROCEDURE DONE"] ?
                @obstetrics[pos]["PROCEDURE DONE"] : "")) : "").gsub(/Spontaneous\sVaginal\sDelivery/i,
          "S.V.D.").gsub(/Caesarean\sSection/i, "C-Section").gsub(/Vacuum\sExtraction\sDelivery/i,
          "Vac. Extr.").gsub("(MVA)", "").gsub(/Manual\sVacuum\sAspiration/i,
          "M.V.A.").gsub(/Evacuation/i, "Evac")

        @labor = (@obstetrics[pos] ? (@obstetrics[pos]["LABOUR DURATION"] ?
              @obstetrics[pos]["LABOUR DURATION"] : "") : "")

        @labor = (@labor.length > 5 ? truncate(@labor,5) : @labor)

        @cond = (@obstetrics[pos] ? (@obstetrics[pos]["CONDITION AT BIRTH"] ?
              @obstetrics[pos]["CONDITION AT BIRTH"] : "") : "").titleize

        @birt_weig = (@obstetrics[pos] ? (@obstetrics[pos]["BIRTH WEIGHT"] ?
              @obstetrics[pos]["BIRTH WEIGHT"] : "") : "")
        @birt_weig = @birt_weig.match(/Small/i) ? "<2.5 kg" : (@birt_weig.match(/Big/i) ? ">4.5 kg" : @birt_weig)

        @dea = (@obstetrics[pos] ? (@obstetrics[pos]["AGE AT DEATH"] ?
              (@obstetrics[pos]["AGE AT DEATH"].to_s.match(/\.[1-9]/) ? @obstetrics[pos]["AGE AT DEATH"].to_s :
                @obstetrics[pos]["AGE AT DEATH"].to_s) : "") : "").to_s +
          (@obstetrics[pos] ? (@obstetrics[pos]["UNITS OF AGE OF CHILD"] ?
              @obstetrics[pos]["UNITS OF AGE OF CHILD"] : "") : "")

        if pos <= 3

          label.draw_text(pos.to_s,28,(85 + (60 * pos)),0,2,1,1,false)

          label.draw_text((@obstetrics[pos] ? (@obstetrics[pos]["YEAR OF BIRTH"] ?
                  (@obstetrics[pos]["YEAR OF BIRTH"].to_i > 0 ? @obstetrics[pos]["YEAR OF BIRTH"].to_i :
                    "????") : "") : ""),58,(70 + (60 * pos)),0,2,1,1,false)

          if @place.length < 9
            label.draw_text(@place,111,(70 + (60 * pos)),0,2,1,1,false)
          else
            @place = paragraphate(@place)

            (0..(@place.length)).each{|p|
              label.draw_text(@place[p].to_s,111,(70 + (60 * pos) + (18 * p)),0,2,1,1,false)
            }
          end

          label.draw_text(@gest,225,(70 + (60 * pos)),0,2,1,1,false)

          #label.draw_text(@labor,300,(70 + (60 * pos)),0,2,1,1,false)

          label.draw_text(@delmode,300,(70 + (60 * pos)),0,2,1,1,false)

          label.draw_text(@cond,420,(70 + (60 * pos)),0,2,1,1,false)

          label.draw_text(@birt_weig,539,(70 + (60 * pos)),0,2,1,1,false)

          label.draw_text((@obstetrics[pos] ? (@obstetrics[pos]["ALIVE"] ?
                  @obstetrics[pos]["ALIVE"] : "") : ""),647,(70 + (60 * pos)),0,2,1,1,false)

          if @dea.length < 10
            label.draw_text(@dea,708,(70 + (60 * pos)),0,2,1,1,false)
          else
            @dea = paragraphate(@dea, 4)

            (0..(@dea.length)).each{|p|
              label.draw_text(@dea[p],708,(70 + (60 * pos) + (18 * p)),0,2,1,1,false)
            }
          end

          label.draw_line(20,((135 + (45 * pos)) <= 305 ? (125 + (60 * pos)) : 305),800,2,0)

        elsif pos >= 4 && pos <= 8
          if pos == 4
            label2.draw_line(20,30,800,2,0)
            label2.draw_line(20,30,2,275,0)
            label2.draw_line(20,305,800,2,0)
            label2.draw_line(805,30,2,275,0)

            label2.draw_line(55,30,2,275,0)
            label2.draw_line(105,30,2,275,0)
            label2.draw_line(220,30,2,275,0)
            label2.draw_line(295,30,2,275,0)
            label2.draw_line(380,30,2,275,0)
            label2.draw_line(510,30,2,275,0)
            label2.draw_line(615,30,2,275,0)
            label2.draw_line(683,30,2,275,0)
            label2.draw_line(740,30,2,275,0)
          end
          label2.draw_text(pos,28,((55 * (pos - 3))),0,2,1,1,false)

          label2.draw_text((@obstetrics[pos] ? (@obstetrics[pos]["YEAR OF BIRTH"] ?
                  (@obstetrics[pos]["YEAR OF BIRTH"].to_i > 0 ? @obstetrics[pos]["YEAR OF BIRTH"].to_i :
                    "????") : "") : ""),58,((55 * (pos - 3)) - 13),0,2,1,1,false)

          if @place.length < 8
            label2.draw_text(@place,111,((55 * (pos - 3)) - 13),0,2,1,1,false)
          else
            @place = paragraphate(@place)

            (0..(@place.length)).each{|p|
              label2.draw_text(@place[p],111,(55 * (pos - 3) + (18 * p))-17,0,2,1,1,false)
            }
          end

          label2.draw_text(@gest,225,((55 * (pos - 3)) - 13),0,2,1,1,false)

          label2.draw_text(@labor,300,((55 * (pos - 3)) - 13),0,2,1,1,false)

          label2.draw_text(@delmode,385,(55 * (pos - 3)),0,2,1,1,false)

          if @cond.length < 6
            label2.draw_text(@cond,515,((55 * (pos - 3)) - 13),0,2,1,1,false)
          else
            @cond = paragraphate(@cond, 6)

            (0..(@cond.length)).each{|p|
              label2.draw_text(@cond[p],515,(55 * (pos - 3) + (18 * p))-17,0,2,1,1,false)
            }
          end

          if @birt_weig.length < 6
            label2.draw_text(@birt_weig,620,((55 * (pos - 3)) - 13),0,2,1,1,false)
          else
            @birt_weig = paragraphate(@birt_weig, 4)

            (0..(@birt_weig.length)).each{|p|
              label2.draw_text(@birt_weig[p],620,(55 * (pos - 3) + (18 * p))-17,0,2,1,1,false)
            }
          end

          label2.draw_text((@obstetrics[pos] ? (@obstetrics[pos]["ALIVE"] ?
                  @obstetrics[pos]["ALIVE"] : "") : ""),687,((55 * (pos - 3)) - 13),0,2,1,1,false)

          if @dea.length < 10
            label2.draw_text(@dea,745,((55 * (pos - 3)) - 13),0,2,1,1,false)
          else
            @dea = paragraphate(@dea, 4)

            (0..(@dea.length)).each{|p|
              label2.draw_text(@dea[p],745,(55 * (pos - 3) + (18 * p))-17,0,2,1,1,false)
            }
          end

          label2.draw_line(20,(((55 * (pos - 3)) + 35) <= 305 ? ((55 * (pos - 3)) + 35) : 305),800,2,0)
          label2set = true
        else
          if pos == 9
            label3.draw_line(20,30,800,2,0)
            label3.draw_line(20,30,2,275,0)
            label3.draw_line(20,305,800,2,0)
            label3.draw_line(805,30,2,275,0)

            label3.draw_line(55,30,2,275,0)
            label3.draw_line(105,30,2,275,0)
            label3.draw_line(220,30,2,275,0)
            label3.draw_line(295,30,2,275,0)
            label3.draw_line(380,30,2,275,0)
            label3.draw_line(510,30,2,275,0)
            label3.draw_line(615,30,2,275,0)
            label3.draw_line(683,30,2,275,0)
            label3.draw_line(740,30,2,275,0)
          end
          label3.draw_text(pos,28,((55 * (pos - 8))),0,2,1,1,false)

          label3.draw_text((@obstetrics[pos] ? (@obstetrics[pos]["YEAR OF BIRTH"] ?
                  (@obstetrics[pos]["YEAR OF BIRTH"].to_i > 0 ? @obstetrics[pos]["YEAR OF BIRTH"].to_i :
                    "????") : "") : ""),58,((55 * (pos - 8)) - 13),0,2,1,1,false)

          if @place.length < 8
            label3.draw_text(@place,111,((55 * (pos - 8)) - 13),0,2,1,1,false)
          else
            @place = paragraphate(@place)

            (0..(@place.length)).each{|p|
              label3.draw_text(@place[p],111,(55 * (pos - 8) + (18 * p))-17,0,2,1,1,false)
            }
          end

          label3.draw_text(@gest,225,((55 * (pos - 8)) - 13),0,2,1,1,false)

          label3.draw_text(@labor,300,((55 * (pos - 8)) - 13),0,2,1,1,false)

          if @delmode.length < 11
            label3.draw_text(@delmode,385,(55 * (pos - 8)),0,2,1,1,false)
          else
            @delmode = paragraphate(@delmode)

            (0..(@delmode.length)).each{|p|
              label3.draw_text(@delmode[p],385,(55 * (pos - 8) + (18 * p))-17,0,2,1,1,false)
            }
          end

          if @cond.length < 6
            label3.draw_text(@cond,515,((55 * (pos - 8)) - 13),0,2,1,1,false)
          else
            @cond = paragraphate(@cond, 6)

            (0..(@cond.length)).each{|p|
              label3.draw_text(@cond[p],515,(55 * (pos - 8) + (18 * p))-17,0,2,1,1,false)
            }
          end

          if @birt_weig.length < 6
            label3.draw_text(@birt_weig,620,(70 + (60 * pos)),0,2,1,1,false)
          else
            @birt_weig = paragraphate(@birt_weig, 4)

            (0..(@birt_weig.length)).each{|p|
              label3.draw_text(@birt_weig[p],620,(55 * (pos - 3) + (18 * p))-17,0,2,1,1,false)
            }
          end

          label3.draw_text((@obstetrics[pos] ? (@obstetrics[pos]["ALIVE"] ?
                  @obstetrics[pos]["ALIVE"] : "") : ""),687,((55 * (pos - 8)) - 13),0,2,1,1,false)

          if @dea.length < 6
            label3.draw_text(@dea,745,((55 * (pos - 3)) - 13),0,2,1,1,false)
          else
            @dea = paragraphate(@dea, 4)

            (0..(@dea.length)).each{|p|
              label3.draw_text(@dea[p],745,(55 * (pos - 3) + (18 * p))-17,0,2,1,1,false)
            }
          end

          label3.draw_line(20,(((55 * (pos - 8)) + 35) <= 305 ? ((55 * (pos - 8)) + 35) : 305),800,2,0)
          label3set = true
        end

      end

      if label3set
        label.print(1) + label2.print(1) + label3.print(1)
      elsif label2set
        label.print(1) + label2.print(1)
      else
        label.print(1)
    end
  end

      private

      def getEquivFundalWeeks(fundal_height)

        fundus_weeks = 0

        if (fundal_height <= 12)

          fundus_weeks = 13;

        elsif (fundal_height == 13)

          fundus_weeks = 14

        elsif (fundal_height == 14)

          fundus_weeks = 16

        elsif (fundal_height == 15)

          fundus_weeks = 17

        elsif (fundal_height == 16)

          fundus_weeks = 18

        elsif (fundal_height == 17)

          fundus_weeks = 19

        elsif (fundal_height == 18)

          fundus_weeks = 20

        elsif (fundal_height == 19)

          fundus_weeks = 21

        elsif (fundal_height == 20)

          fundus_weeks = 22

        elsif (fundal_height == 21)

          fundus_weeks = 24

        elsif (fundal_height == 22)

          fundus_weeks = 25

        elsif (fundal_height == 23)

          fundus_weeks = 26

        elsif (fundal_height == 24)

          fundus_weeks = 27

        elsif (fundal_height == 25)

          fundus_weeks = 28

        elsif (fundal_height == 26)

          fundus_weeks = 29

        elsif (fundal_height == 27)

          fundus_weeks = 30

        elsif (fundal_height == 28)

          fundus_weeks = 32

        elsif (fundal_height == 29)

          fundus_weeks = 33

        elsif (fundal_height == 30)

          fundus_weeks = 34

        elsif (fundal_height == 31)

          fundus_weeks = 35

        elsif (fundal_height == 32)

          fundus_weeks = 36

        elsif (fundal_height == 33)

          fundus_weeks = 37

        elsif (fundal_height == 34)

          fundus_weeks = 38

        elsif (fundal_height == 35)

          fundus_weeks = 39

        elsif (fundal_height == 36)

          fundus_weeks = 40

        elsif (fundal_height == 37)

          fundus_weeks = 42

        elsif (fundal_height > 37)

          fundus_weeks = 42

        end
        return fundus_weeks
      end

      def getObsValue(obs)
        if !obs.value_coded.blank?
          concept = ConceptName.find_by concept_id: obs.value_coded
          return concept.name
        end

        if !obs.value_text.blank?
          return obs.value_text
        end

        unless obs.value_numeric.nil?
          return obs.value_numeric
        end

        if !obs.value_datetime.blank?
          return obs.value_datetime.to_date.strftime("%Y-%m-%d")
        end

        return ""
      end

      def paragraphate(string, collen = 8, rows = 2)
        arr = []

        if string.nil?
          return arr
        end

        string = string.strip

        (0..rows).each{|p|
          if !(string[p*collen,collen]).nil?
            if p == rows
              arr << (string[p*collen,collen] + ".") if !(string[p*collen,collen]).nil?
            elsif string[((p*collen) + collen),1] != " " && !string.strip[((p+1)*collen),collen].nil? &&
                string[(((p+1)*collen) + collen),1] != " "
              arr << (string[p*collen,collen] + "-") if !(string[p*collen,collen]).nil?
            else
              arr << string[p*collen,collen] if !(string[p*collen,collen]).nil?
            end
          end
        }
        arr
      end

      end

    end