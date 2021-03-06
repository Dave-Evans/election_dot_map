options(stringsAsFactor=F)
library(rgdal)
library(raster)
library(rgeos)
library(foreign)
library(RColorBrewer)
library(classInt)

#library(maptools)
#	blue
	#67a9cf
#	red
	#ef8a62

#file_wards = "/media/devans/KINGSTON/misc/election_dot_map/wards_2011"
#file_blocks = "/media/devans/KINGSTON/misc/election_dot_map/blocks"
#file_ed_ward = "/media/devans/KINGSTON/misc/election_dot_map/ElectionData_by_Ward.dbf"
#file_ed_block = "/media/devans/KINGSTON/misc/election_dot_map/ElectionData_by_Block.dbf"

file_wards = "C:/workspace/checkout_wards/election_dot_map/wards_2011"
file_blocks = "C:/workspace/checkout_wards/election_dot_map/blocks"
file_ed_ward = "C:/workspace/checkout_wards/election_dot_map/ElectionData_by_Ward.dbf"
file_ed_block = "C:/workspace/checkout_wards/election_dot_map/ElectionData_by_Blocks.dbf"

file_voterPoints = "~/voterPoints.csv"
#colrs = c("#0571b0", "#ca0020", "#b2abd2", "#999999")
createVoterXY <- function(voterKind, block){
	#returns a dataframe of x, y, class (voterKind) and color
#	voterKind = "NOVOTE"
#	ward = wrd
#	block = blck
	
	if (block@data$PERSONS18.x == 0) { return(data.frame()) } 
#	prp = block@data$PERSONS18/ward@data$PERSONS18.x
	
	if (voterKind == "DEM"){
		nSamp = block@data[["PRES_DEM12"]]
		colr = "#0571b0"
	} else if (voterKind == "REP") {
		nSamp = block@data[["PRES_REP12"]]
		colr = "#ca0020"
	} else if (voterKind == "IND") {
		nSamp = (block@data[["PRES_TOT12"]] - (block@data[["PRES_REP12"]] + block@data[["PRES_DEM12"]]))
		colr = "#b2abd2"
	} else {
		nSamp = (block@data[["PERSONS18.x"]] - block@data[["PRES_TOT12"]])
		colr = "#9999999"
	}
	
#	print(paste("Proportion", voterKind, "=", nSamp))
	
	# going to be issues here due to missampled attempts
	print(length(nSamp))
	if (round(nSamp) <= 0){ return(data.frame())}
	b_notDone = TRUE
	while (b_notDone){
		err = try({samp = spsample(block, round(nSamp), 'random')},
				silent=T)
		if (class(err) == "try-error"){
			b_notDone = TRUE
			print("----------")
			print("Redoing")
			print("------------")
		} else {
			b_notDone = FALSE
		}
	}
	
	if (length(samp) == 0){ return(data.frame())}
	gcs_samp = spTransform(samp, CRS("+proj=longlat +datum=NAD83"))
	tmpDF = paste(
		coordinates(gcs_samp)[,1],
		coordinates(gcs_samp)[,2],
		voterKind,
		colr,
		sep=",")
#	tmpDF = data.frame(
#				x=(coordinates(gcs_samp))[,1],
#				y=(coordinates(gcs_samp))[,2],
#				voterType=voterKind,
#				COLOR=colr)
	return(tmpDF)	
}


#		demVote = spsample(wrd, dem_count, type='random')
#		# plot(demVote, add=T, col=colrs[1], pch=20, cex=0.01)
#		df_votes = rbind(df_votes,
#				data.frame(
#						x=coordinates(demVote)[,1],
#						y=coordinates(demVote)[,2],
#						Class="dem",
#						Colr=colrs[1]))
voterTypes = c("DEM", "REP", "IND", "NOVOTE")

wards = readOGR(
			dsn=dirname(file_wards),
			layer=basename(file_wards))

#blocks = readShapeSpatial(file_blocks)

blocks = readOGR(
			dsn=dirname(file_blocks),
			layer=basename(file_blocks))

ed = read.dbf(file_ed_block)
blocks = merge(blocks, ed, by="GEOID10")

### test ###


#wards = subset(wards, CNTY_NAME.x == "Adams")
#blocks = subset(blocks, CNTY_NAME == "Adams")

#for (i in 1:length(wards)){
#	print(paste("Working on", i))
#	print(paste("    County of", wards@data$CNTY_NAME.x[i]))
#	wrd = wards[i,]
#	wrdid = wrd@data$WARD_FIPS
##	pop18_wrd = wrd@data$PERSONS18.x
#	blcks = subset(blocks, WARD_FIPS == wrdid)
dfVote = data.frame()
cat("lon,lat,voterType,COLOR", file=file_voterPoints, append=FALSE, sep="\n")
for (j in 1:length(blocks)){
	print(paste("I'm working on number: ", j))
	blck = blocks[j,]
#		pop18_blck = blck@data$PERSONS18 
#		prp = round(pop18_blck/pop18_wrd, 3)

		
		

	for (voter in voterTypes) {
		tmpDF = createVoterXY(voter,blck)
#		if (nrow(tmpDF)==0){next}
#		dfVote = rbind(dfVote, tmpDF)
		if (class(tmpDF)=="data.frame") { 
			print("    skipping")
			next
		}
		cat(tmpDF, file=file_voterPoints, append=TRUE, sep="\n")	
	}
	close(file(file_voterPoints))
	
}
#}

dfVote$id = 1:nrow(dfVote)
write.csv(
	dfVote,
	file_voterPoints,
	row.names=F)
####### End Adams County Test ########
####### Junk Below ###################
coordinates(dfVote) <- c("x", "y")
proj4string(dfVote) <- projection(wards)
writeOGR(
		dfVote,
		dsn=dirname(file_voterPoints),
		layer=basename(file_voterPoints),
		driver="ESRI Shapefile")
#plot(wards_adams)
#plot(dfVote, add=T, col=dfVote@data$COLOR)
### ---- ###

if !(file.exists(paste0(file_waterClip, ".shp"))){
	
	wards = readOGR(
		dsn=dirname(file_wards),
		layer=basename(file_wards))
	water = readOGR(
		dsn=dirname(file_water),
		layer=basename(file_water))
	
	ed = read.dbf(file_ed)
	wards = merge(wards, ed, by="GEOID10")
	
	waterClip = gDifference(wards, water)
	writeOGR(
		waterClip,
		dsn=dirname(file_waterClip),
		layer=basename(file_waterClip),
		driver="ESRI Shapefile")
	wards = waterClip
} else {
	wards = readOGR(
	dsn=dirname(file_waterClip),
	layer=basename(file_waterClip))
}
proj = CRS(projection(wards))


dane = subset(wards,
	CNTY_FIPS.x == "55025", 
	select=c(
		"PERSONS18.x",
		"PRES_TOT12",
		"PRES_REP12",
		"PRES_DEM12",
		"MCD_NAME.x"))

water = water[gIsValid(water, byid=T),]
		
dane_tst = gDifference(dane, water)
writeOGR(
	dane_tst,
	dsn=dirname(file_wards),
	layer="dane_clip.shp",
	driver="ESRI Shapefile")
totl = "PRES_TOT12"
rbl = "PRES_REP12"
dem = "PRES_DEM12"
prs18 = "PERSONS18.x"
# ind = totl - (rbl + dem)
# novote = prs18 - totl

colrs = c("#0571b0", "#ca0020", "#b2abd2", "#999999")
# pdf("test_dane_vote.pdf", width=8.5, height=11)
# plot(dane,border='white')

df_votes = data.frame()
# for (i in 1:length(wards)){

nad83 = CRS("+init=epsg:4269")
dane = spTransform(dane, nad83)

for (i in 1:length(dane)){	
	# wrd = wards[i,]
	wrd = dane[i,]
	print(paste("Working on: ", wrd@data$MCD_NAME.x))
	
	dem_count = wrd@data[[dem]]
	rep_count = wrd@data[[rbl]]
	
	ind_count = (wrd@data[[totl]] - (wrd@data[[rbl]] + wrd@data[[dem]]))
	novote_count = (wrd@data[[prs18]] - wrd@data[[totl]])
	
	if (dem_count > 0){
		demVote = spsample(wrd, dem_count, type='random')
		# plot(demVote, add=T, col=colrs[1], pch=20, cex=0.01)
		df_votes = rbind(df_votes,
			data.frame(
				x=coordinates(demVote)[,1],
				y=coordinates(demVote)[,2],
				Class="dem",
				Colr=colrs[1]))
	}
	if (rep_count > 0){
		repVote = spsample(wrd, rep_count, type='random')
		# plot(repVote, add=T, col=colrs[2], pch=20, cex=0.01)
		df_votes = rbind(df_votes,
			data.frame(
				x=coordinates(repVote)[,1],
				y=coordinates(repVote)[,2],
				Class="rep",
				Colr=colrs[2]))
	}
	
	if (ind_count > 0){
		indVote = spsample(wrd, ind_count, type='random')
		# plot(indVote, add=T, col=colrs[3], pch=20, cex=0.01)
		df_votes = rbind(df_votes,
			data.frame(
				x=coordinates(indVote)[,1],
				y=coordinates(indVote)[,2],
				Class="ind",
				Colr=colrs[3]))
	}
	# if (dem_count >= rep_count) {
		# plot(repVote, add=T, col=colrs[2], pch=20, cex=0.5)
		# plot(demVote, add=T, col=colrs[1], pch=20, cex=0.5)
		# plot(indVote, add=T, col=colrs[3], pch=20, cex=0.5)
	# } else {
		# plot(demVote, add=T, col=colrs[1], pch=20, cex=0.5)
		# plot(repVote, add=T, col=colrs[2], pch=20, cex=0.5)
		# plot(indVote, add=T, col=colrs[3], pch=20, cex=0.5)
	# }
	
	if (novote_count > 0){
		noVote = spsample(wrd, novote_count, type='random')
		# plot(noVote, add=T, col=colrs[4], pch=20, cex=0.05)
		df_votes = rbind(df_votes,
			data.frame(
				x=coordinates(noVote)[,1],
				y=coordinates(noVote)[,2],
				Class="noVote",
				Colr=colrs[4]))
	}
}

coordinates(df_votes) <- c("x", "y")
proj4string(df_votes) <- "+init=epsg:4269"
m = leaflet() %>%  addTiles()
m %>% addCircles(
	data=df_votes)


# votes = coordinates(df_votes) <- c("x", "y")
# proj4string(votes) <- proj

# writeOGR(
	# votes,
	# dsn=dirname(file_voterPoints),
	#paste .shp?
	# layer=basename(file_voterPoints),
	# driver="ESRI Shapefile")
	

# dev.off()


	








sen24 = subset(wards, SEN==24)
sen24@data$PROPDEM_SEN12 = sen24@data$SEN_DEM12/sen24@data$SEN_TOT12


### ------
fixedClasses5=classIntervals(
	sen24@data$PROPDEM_SEN12,
	5,
	"fixed",
	fixedBreaks=c(0,.40,.48,.52,.60,1))
colcode5 = findColours(fixedClasses5,
	c("#ca0020", "#f4a582", "#e8beff", "#92c5de", "#0571b0"))

### ------
fixedClasses7=classIntervals(
	sen24@data$PROPDEM_SEN12,
	5,
	style="fixed",
	fixedBreaks=c(0,.40,.47,0.49,.51,.53,.60,1))
colcode7 = findColours(fixedClasses7,
	c('#b2182b', '#ef8a62', '#fddbc7', '#f7f7f7', '#d1e5f0', '#67a9cf', "#2166ac"))

### ------
fixedClasses9=classIntervals(
	sen24@data$PROPDEM_SEN12,
	5,
	style="fixed",
	fixedBreaks=c(0,.30,.40,.47,0.49,.51,.53,.60,.70,1))
colcode9 = findColours(fixedClasses9,
	c('#b2182b', '#d6604d', '#f4a582', '#fddbc7', '#f7f7f7', '#d1e5f0', '#92c5de', '#4393c3', "#2166ac"))

dev.new()
plot(sen24, col=colcode5)
plot(sen24, col=colcode7)
plot(sen24, col=colcode9)






## plot(fixedClasses5, c("red", "purple", "blue"))
## colcode5 = findColours(fixedClasses5,
##	c("#FF2626","#FF8A78","#A020F0","#82A0F5", "#1267E6"))
