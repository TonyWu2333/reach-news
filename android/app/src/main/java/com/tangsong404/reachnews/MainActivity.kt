package com.tangsong404.reachnews

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val Ink = Color(0xFF121211)
private val Secondary = Color(0xFF777773)
private val Paper = Color(0xFFF5F5F0)
private val Card = Color(0xFFF1F1ED)
private val Left = Color(0xFF0E94CF)
private val Center = Color(0xFF6F6F6B)
private val Right = Color(0xFFF55538)
private val Gold = Color(0xFFD0BD8F)
private val Purple = Color(0xFF8470B8)

data class Story(val id: String, val title: String, val topic: String, val summary: String, val left: Int, val center: Int, val right: Int, val sources: Int, val time: String, val colors: List<Color>)
data class Collector(val name: String, val source: String, val cadence: String, val items: Int, val status: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)
data class BriefingChannel(val name: String, val summary: String, val schedule: String, val collectors: Int, val unread: Int, val icon: androidx.compose.ui.graphics.vector.ImageVector, val tint: Color, val enabled: Boolean)
data class TrackedEvent(val title: String, val query: String, val updates: Int, val lastUpdated: String, val icon: androidx.compose.ui.graphics.vector.ImageVector, val tint: Color)

private val stories = listOf(
    Story("iran", "Trump Says Iran Ceasefire Is Over After Strait Attacks", "World", "President Donald Trump declared the ceasefire with Iran over after strikes on commercial ships and regional facilities.", 32, 36, 32, 679, "11 hrs ago", listOf(Color(0xFF2D6077), Color(0xFF9BBBC4))),
    Story("flood", "Texas Hill Country Faces Flash Flood Warnings as Abbott Declares Disaster", "United States", "Emergency crews respond as rising water threatens communities across the Texas Hill Country.", 19, 61, 20, 84, "2 hrs ago", listOf(Color(0xFF345A72), Color(0xFF9FB6A0))),
    Story("forest", "Trump administration plans to rescind rule blocking logging on national forest lands", "Environment", "A proposed change would reshape forest management and expand logging access on public lands.", 48, 10, 42, 52, "4 hrs ago", listOf(Color(0xFF1E432D), Color(0xFF78974E))),
    Story("lobby", "Trump axes Biden-era lobbying restrictions", "Politics", "The action erases rules that restricted former officials from engaging in shadow lobbying.", 8, 42, 50, 74, "4 hrs ago", listOf(Color(0xFF2E3240), Color(0xFF9C664B))),
    Story("bank", "U.S. Bank Regulators Warn on Lending Risks for Unauthorized Immigrants", "Business", "Regulators issued new guidance on lending risk, compliance and financial access.", 25, 50, 25, 39, "6 hrs ago", listOf(Color(0xFF263E61), Color(0xFF9EA9BA)))
)

private val collectors = listOf(
    Collector("GitHub Trending", "GitHub", "Daily · 08:00", 24, "Ready", Icons.Default.Code),
    Collector("X watchlist", "X", "Every 2 hours", 18, "Watching", Icons.Default.AlternateEmail),
    Collector("小红书趋势", "小红书", "Daily · 09:30", 31, "Ready", Icons.Default.AutoAwesome)
)
private val channels = listOf(
    BriefingChannel("AI & Agents", "Models, products and the people building them.", "Every day · 08:30", 2, 12, Icons.Default.AutoAwesome, Purple, true),
    BriefingChannel("Technology", "The systems changing how we work and live.", "Every day · 12:00", 3, 8, Icons.Default.Memory, Left, true),
    BriefingChannel("Markets", "Signals and context for the next trading day.", "Weekdays · 17:30", 1, 4, Icons.Default.ShowChart, Gold, true),
    BriefingChannel("Games", "Releases, studios and the culture around play.", "Every day · 19:00", 1, 0, Icons.Default.SportsEsports, Right, false)
)
private val events = listOf(
    TrackedEvent("Open models race", "open source foundation models", 17, "38 min ago", Icons.Default.Sync, Purple),
    TrackedEvent("AI chip export rules", "semiconductor export controls", 6, "Yesterday", Icons.Default.TrackChanges, Gold)
)

class MainActivity : ComponentActivity() { override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); setContent { ReachNewsApp() } } }

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun ReachNewsApp() {
    var tab by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf<Story?>(null) }
    var showSettings by remember { mutableStateOf(false) }
    var askContext by remember { mutableStateOf<String?>(null) }
    MaterialTheme(colorScheme = lightColorScheme(primary = Ink, background = Paper)) {
        if (selected != null) StoryDetail(selected!!, onBack = { selected = null }, onAsk = { askContext = selected!!.title })
        else Scaffold(containerColor = Paper, bottomBar = {
            NavigationBar(containerColor = Color.White) {
                listOf("Briefing" to Icons.Default.MenuBook, "Build" to Icons.Default.Tune, "Following" to Icons.Default.Bookmark).forEachIndexed { index, item -> NavigationBarItem(selected = tab == index, onClick = { tab = index }, icon = { Icon(item.second, item.first) }, label = { Text(item.first) }) }
            }
        }) { padding ->
            when (tab) {
                0 -> Briefing({ selected = it }, { showSettings = true }, Modifier.padding(padding))
                1 -> BuildWorkspace(Modifier.padding(padding), onStory = { selected = it }, onAsk = { askContext = it })
                else -> Following({ selected = it }, Modifier.padding(padding), onEvent = { askContext = it.title })
            }
        }
        if (showSettings) AlertDialog(onDismissRequest = { showSettings = false }, confirmButton = { TextButton(onClick = { showSettings = false }) { Text("Done") } }, title = { Text("Settings") }, text = { Text("Your channels and collectors are private to your account. Cached items are only used to assemble your brief.") })
        askContext?.let { AskAgentDialog(it, onDismiss = { askContext = null }) }
    }
}

@Composable fun Header(title: String, subtitle: String? = null) { Column(Modifier.padding(bottom = 18.dp)) { Text(title, fontSize = 39.sp, fontWeight = FontWeight.Black, color = Ink); subtitle?.let { Text(it, color = Secondary, lineHeight = 20.sp) } } }

@Composable fun Briefing(onStory: (Story) -> Unit, onSettings: () -> Unit, modifier: Modifier = Modifier) {
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(15.dp), contentPadding = PaddingValues(top = 20.dp, bottom = 24.dp)) {
        item { Row(verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("TUESDAY, JUNE 17", fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp, color = Secondary); Text("Your daily perspective.", fontSize = 35.sp, fontWeight = FontWeight.Black, color = Ink) }; Icon(Icons.Default.AccountCircle, null, Modifier.size(38.dp).clickable { onSettings() }) } }
        item { DailyCard() }
        item { PulseCard() }
        item { Text("YOUR CHANNELS", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }
        items(channels.filter { it.enabled }) { ChannelRow(it, showChevron = true) }
        item { Text("TRACKED EVENTS", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }
        items(events) { EventRow(it, onClick = {}) }
        item { Text("LATEST STORIES", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }
        items(stories) { StoryCard(it, onStory, featured = it == stories.first()) }
    }
}

@Composable fun DailyCard() { Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Card).padding(18.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("THE BIG PICTURE", fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.3.sp); Text("The Last 24", fontSize = 36.sp, fontWeight = FontWeight.Black); Text("Your world, in a 4-minute read.", color = Secondary, fontSize = 12.sp) }; Icon(Icons.Default.Newspaper, null, Modifier.size(46.dp)) } }
@Composable fun PulseCard() { Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Gold.copy(alpha = .25f)).padding(15.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Refresh, null, Modifier.size(36.dp)); Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text("COLLECTOR PULSE", fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp); Text("3 collectors refreshed 73 cached items", fontWeight = FontWeight.SemiBold); Text("Next brief ready at 08:30", color = Secondary, fontSize = 12.sp) }; Icon(Icons.Default.ChevronRight, null) } }

@Composable fun BuildWorkspace(modifier: Modifier = Modifier, onStory: (Story) -> Unit, onAsk: (String) -> Unit) {
    var mode by remember { mutableStateOf("Channels") }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp), contentPadding = PaddingValues(top = 20.dp, bottom = 24.dp)) {
        item { Header("Build your brief", "Configure collectors, channels and events for each daily run.") }
        item { Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { listOf("Channels", "Collectors", "Stories").forEach { FilterChip(selected = mode == it, onClick = { mode = it }, label = { Text(it) }) } } }
        if (mode == "Channels") {
            item { Text("DAILY CHANNELS", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }
            items(channels) { ChannelRow(it, showChevron = true) }
            item { Text("Track a developing story as its own daily channel.", color = Secondary, fontSize = 13.sp) }
            items(events) { EventRow(it, onClick = { onAsk(it.title) }) }
        } else if (mode == "Collectors") {
            item { Text("YOUR COLLECTORS", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }
            item { Text("Collectors belong to your channels and events. The source cache only deduplicates recent items internally.", color = Secondary, fontSize = 13.sp, lineHeight = 18.sp) }
            items(collectors) { CollectorCard(it) }
            item { Button(onClick = {}, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Ink)) { Icon(Icons.Default.Add, null); Spacer(Modifier.width(6.dp)); Text("Add a collector") } }
        } else {
            item { StoryExplore(onStory) }
        }
    }
}

@Composable fun StoryExplore(onStory: (Story) -> Unit) { var query by remember { mutableStateOf("") }; val filtered = stories.filter { query.isBlank() || (it.title + it.topic + it.summary).contains(query, ignoreCase = true) }; OutlinedTextField(value = query, onValueChange = { query = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("Search stories and topics") }, leadingIcon = { Icon(Icons.Default.Search, null) }, singleLine = true); Spacer(Modifier.height(12.dp)); filtered.forEach { StoryCard(it, onStory) } }
@Composable fun Following(onStory: (Story) -> Unit, modifier: Modifier = Modifier, onEvent: (TrackedEvent) -> Unit) { LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp), contentPadding = PaddingValues(top = 20.dp, bottom = 24.dp)) { item { Header("Following", "Your interests, tracked events and saved stories.") }; item { Text("TRACKED EVENTS", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }; items(events) { EventRow(it, onClick = { onEvent(it) }) }; item { Text("YOUR TOPICS", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }; item { Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) { listOf("World", "Politics", "Technology").forEach { AssistChip(onClick = {}, label = { Text(it) }) } } }; item { Text("SAVED STORIES", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }; items(stories.take(2)) { StoryCard(it, onStory) } } }

@Composable fun ChannelRow(channel: BriefingChannel, showChevron: Boolean) { Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Card).padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(channel.icon, null, tint = channel.tint, modifier = Modifier.size(25.dp)); Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Row(verticalAlignment = Alignment.CenterVertically) { Text(channel.name, fontWeight = FontWeight.Bold); if (!channel.enabled) { Spacer(Modifier.width(6.dp)); Text("PAUSED", color = Secondary, fontSize = 9.sp, fontWeight = FontWeight.Bold) } }; Text(channel.schedule, color = Secondary, fontSize = 12.sp) }; if (channel.unread > 0) Text("${channel.unread}", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.size(25.dp).background(Ink, CircleShape).wrapContentSize(Alignment.Center)); if (showChevron) Icon(Icons.Default.ChevronRight, null, tint = Secondary) } }
@Composable fun CollectorCard(collector: Collector) { Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Card).padding(15.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { Row(verticalAlignment = Alignment.CenterVertically) { Icon(collector.icon, null, tint = Purple); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(collector.name, fontWeight = FontWeight.Bold); Text(collector.source, color = Secondary, fontSize = 12.sp) }; Text(collector.status.uppercase(), color = Purple, fontSize = 10.sp, fontWeight = FontWeight.Bold) }; Row { Text(collector.cadence, color = Secondary, fontSize = 12.sp); Spacer(Modifier.weight(1f)); Text("${collector.items} cached items", color = Secondary, fontSize = 12.sp) } } }
@Composable fun EventRow(event: TrackedEvent, onClick: () -> Unit) { Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Card).clickable { onClick() }.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(event.icon, null, tint = event.tint, modifier = Modifier.size(25.dp)); Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text(event.title, fontWeight = FontWeight.Bold); Text("${event.updates} updates · ${event.lastUpdated}", color = Secondary, fontSize = 12.sp) }; Icon(Icons.Default.ChevronRight, null, tint = Secondary) } }

@Composable fun StoryCard(story: Story, onClick: (Story) -> Unit, featured: Boolean = false) { Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Card).clickable { onClick(story) }.padding(15.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { StoryImage(story, if (featured) 190 else 90); Text(if (story.left < 10 || story.right < 10) "◐ Blindspot" else "● Balanced coverage", fontSize = 12.sp, color = Secondary); Text(story.title, fontSize = if (featured) 24.sp else 19.sp, fontWeight = FontWeight.Bold, color = Ink); if (featured) Text(story.summary, color = Secondary, lineHeight = 20.sp); BiasBar(story); Text("${story.time}  ·  ${story.sources} sources", color = Secondary, fontSize = 12.sp) } }
@Composable fun StoryImage(story: Story, height: Int) { Box(Modifier.fillMaxWidth().height(height.dp).clip(RoundedCornerShape(9.dp)).background(Brush.linearGradient(story.colors)), contentAlignment = Alignment.Center) { Icon(Icons.Default.Cloud, null, Modifier.size(56.dp), tint = Color.White.copy(alpha = .72f)) } }
@Composable fun BiasBar(story: Story) { Row(Modifier.fillMaxWidth().height(7.dp).clip(RoundedCornerShape(5.dp))) { Box(Modifier.weight(story.left.toFloat()).fillMaxHeight().background(Left)); Box(Modifier.weight(story.center.toFloat()).fillMaxHeight().background(Center)); Box(Modifier.weight(story.right.toFloat()).fillMaxHeight().background(Right)) } }

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun StoryDetail(story: Story, onBack: () -> Unit, onAsk: () -> Unit) { Scaffold(topBar = { TopAppBar(title = { Text("Story") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, actions = { IconButton(onClick = {}) { Icon(Icons.Default.BookmarkBorder, null) }; IconButton(onClick = {}) { Icon(Icons.Default.Share, null) } }) }) { padding -> LazyColumn(Modifier.padding(padding).padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(18.dp), contentPadding = PaddingValues(bottom = 24.dp)) { item { StoryImage(story, 230) }; item { Text(story.topic.uppercase(), fontSize = 12.sp, color = Secondary, fontWeight = FontWeight.Bold) }; item { Text(story.title, fontSize = 39.sp, fontWeight = FontWeight.Black, color = Ink) }; item { Text(story.summary, fontSize = 18.sp, color = Secondary, lineHeight = 26.sp) }; item { Button(onClick = onAsk, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Ink)) { Icon(Icons.Default.AutoAwesome, null); Spacer(Modifier.width(8.dp)); Text("Ask the agent about this story") } }; item { Text("Coverage", fontWeight = FontWeight.Bold, fontSize = 18.sp) }; item { BiasBar(story) }; item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Metric("Coverage", "${story.sources} sources", Modifier.weight(1f)); Metric("Bias", "Balanced", Modifier.weight(1f)) } }; item { Text("Where sources agree", fontSize = 28.sp, fontWeight = FontWeight.Black) }; item { Text(story.title + ". " + story.summary, lineHeight = 24.sp) }; item { Text("Where sources disagree", fontSize = 28.sp, fontWeight = FontWeight.Black) }; item { Text("Coverage differs on responsibility, consequences and the path forward. Read the original reporting for the complete picture.", lineHeight = 24.sp) } } } }
@Composable fun Metric(title: String, value: String, modifier: Modifier = Modifier) { Column(modifier.clip(RoundedCornerShape(12.dp)).background(Card).padding(14.dp)) { Text(title, color = Secondary); Text(value, fontWeight = FontWeight.Medium) } }
@Composable fun AskAgentDialog(context: String, onDismiss: () -> Unit) { var prompt by remember { mutableStateOf("") }; var answer by remember { mutableStateOf("I’m watching $context. Ask for a timeline, the latest change or more context.") }; AlertDialog(onDismissRequest = onDismiss, confirmButton = { TextButton(onClick = { if (prompt.isNotBlank()) { answer = "Mock answer: I found 6 cached updates related to $context. The immediate change is clear; long-term impact remains contested."; prompt = "" } }) { Text("Ask") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("Done") } }, title = { Text("Ask the agent") }, text = { Column(verticalArrangement = Arrangement.spacedBy(12.dp)) { Text(answer, color = Secondary); OutlinedTextField(value = prompt, onValueChange = { prompt = it }, placeholder = { Text("Ask about this story…") }, singleLine = true) } }) }
