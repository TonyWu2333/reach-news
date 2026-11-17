package com.tangsong404.reachnews

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
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
private val Left = Color(0xFF0E94CF)
private val Center = Color(0xFF6F6F6B)
private val Right = Color(0xFFF55538)

data class GlassStyle(val opacity: Float = 0.66f, val radius: Dp = 26.dp, val tint: Float = 0.10f)
val LocalGlassStyle = compositionLocalOf { GlassStyle() }

@Composable
fun Modifier.liquidGlass(): Modifier {
    val style = LocalGlassStyle.current
    val shape = RoundedCornerShape(style.radius)
    return this
        .shadow(12.dp, shape, ambientColor = Ink.copy(alpha = 0.12f), spotColor = Ink.copy(alpha = 0.18f))
        .clip(shape)
        .background(Color.White.copy(alpha = style.opacity))
        .border(1.dp, Color.White.copy(alpha = 0.62f), shape)
}

data class Story(val id: String, val title: String, val topic: String, val summary: String, val left: Int, val center: Int, val right: Int, val sources: Int, val time: String, val colors: List<Color>)

private val stories = listOf(
    Story("iran", "Trump Says Iran Ceasefire Is Over After Strait Attacks", "World", "President Donald Trump declared the ceasefire with Iran over after strikes on commercial ships and regional facilities.", 32, 36, 32, 679, "11 hrs ago", listOf(Color(0xFF2D6077), Color(0xFF9BBBC4))),
    Story("flood", "Texas Hill Country Faces Flash Flood Warnings as Abbott Declares Disaster", "United States", "Emergency crews respond as rising water threatens communities across the Texas Hill Country.", 19, 61, 20, 84, "2 hrs ago", listOf(Color(0xFF345A72), Color(0xFF9FB6A0))),
    Story("forest", "Trump administration plans to rescind rule blocking logging on national forest lands", "Environment", "A proposed change would reshape forest management and expand logging access on public lands.", 48, 10, 42, 52, "4 hrs ago", listOf(Color(0xFF1E432D), Color(0xFF78974E))),
    Story("lobby", "Trump axes Biden-era lobbying restrictions", "Politics", "The action erases rules that restricted former officials from engaging in shadow lobbying.", 8, 42, 50, 74, "4 hrs ago", listOf(Color(0xFF2E3240), Color(0xFF9C664B))),
    Story("bank", "U.S. Bank Regulators Warn on Lending Risks for Unauthorized Immigrants", "Business", "Regulators issued new guidance on lending risk, compliance and financial access.", 25, 50, 25, 39, "6 hrs ago", listOf(Color(0xFF263E61), Color(0xFF9EA9BA)))
)

class MainActivity : ComponentActivity() { override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); setContent { ReachNewsApp() } } }

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun ReachNewsApp() {
    var tab by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf<Story?>(null) }
    var showSettings by remember { mutableStateOf(false) }
    var glassOpacity by remember { mutableFloatStateOf(0.66f) }
    var glassRadius by remember { mutableFloatStateOf(26f) }
    MaterialTheme(colorScheme = lightColorScheme(primary = Ink, background = Color.White)) {
        CompositionLocalProvider(LocalGlassStyle provides GlassStyle(glassOpacity, glassRadius.dp)) {
            if (selected != null) StoryDetail(selected!!, onBack = { selected = null })
            else Scaffold(bottomBar = { FloatingNavigationBar(tab) { tab = it } }) { padding ->
                when (tab) {
                    0 -> Briefing({ selected = it }, { showSettings = true }, Modifier.padding(padding))
                    1 -> Explore({ selected = it }, Modifier.padding(padding))
                    else -> Following({ selected = it }, Modifier.padding(padding))
                }
            }
            if (showSettings) GlassSettingsDialog(glassOpacity, { glassOpacity = it }, glassRadius, { glassRadius = it }, { showSettings = false })
        }
    }
}

@Composable
fun FloatingNavigationBar(selected: Int, onSelect: (Int) -> Unit) {
    val tabs = listOf("Briefing" to Icons.Default.MenuBook, "Explore" to Icons.Default.Search, "Following" to Icons.Default.Bookmark)
    Row(Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 8.dp).liquidGlass().padding(5.dp), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        tabs.forEachIndexed { index, item ->
            Row(Modifier.weight(1f).height(43.dp).clip(RoundedCornerShape(24.dp)).background(if (index == selected) Color.White.copy(alpha = .82f) else Color.Transparent).clickable { onSelect(index) }, horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                Icon(item.second, null, Modifier.size(17.dp), tint = if (index == selected) Ink else Secondary)
                if (index == selected) Text(item.first, Modifier.padding(start = 7.dp), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Ink)
            }
        }
    }
}

@Composable fun Header(title: String, subtitle: String? = null) { Column(Modifier.padding(bottom = 18.dp)) { Text(title, fontSize = 39.sp, fontWeight = FontWeight.Black, color = Ink); subtitle?.let { Text(it, color = Secondary, lineHeight = 20.sp) } } }

@Composable fun Briefing(onStory: (Story) -> Unit, onSettings: () -> Unit, modifier: Modifier = Modifier) {
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(16.dp), contentPadding = PaddingValues(top = 20.dp, bottom = 24.dp)) {
        item { Row(verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("TUESDAY, JUNE 17", fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp, color = Secondary); Text("Your daily perspective.", fontSize = 35.sp, fontWeight = FontWeight.Black, color = Ink) }; Icon(Icons.Default.AccountCircle, null, Modifier.size(38.dp).clickable { onSettings() }) } }
        item { DailyCard() }
        item { Text("TOP STORIES", fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = Secondary) }
        items(stories) { StoryCard(it, onStory, featured = it == stories.first()) }
    }
}

@Composable fun DailyCard() { Row(Modifier.fillMaxWidth().liquidGlass().padding(18.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("THE BIG PICTURE", fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.3.sp); Text("The Last 24", fontSize = 36.sp, fontWeight = FontWeight.Black); Text("Your world, in a 4-minute read.", color = Secondary, fontSize = 12.sp) }; Icon(Icons.Default.Newspaper, null, Modifier.size(46.dp)) } }

@Composable fun Explore(onStory: (Story) -> Unit, modifier: Modifier = Modifier) {
    var query by remember { mutableStateOf("") }
    val filtered = stories.filter { query.isBlank() || (it.title + it.topic + it.summary).contains(query, ignoreCase = true) }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp), contentPadding = PaddingValues(top = 20.dp, bottom = 24.dp)) {
        item { Header("Explore", "Go beyond your usual headlines.") }
        item { OutlinedTextField(value = query, onValueChange = { query = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("Search stories and topics") }, leadingIcon = { Icon(Icons.Default.Search, null) }, singleLine = true) }
        item { Text("Topics to explore", fontWeight = FontWeight.Bold, fontSize = 18.sp) }
        item { Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) { listOf("World", "Politics", "Environment", "Business").forEach { AssistChip(onClick = { query = it }, label = { Text(it) }) } } }
        items(filtered) { StoryCard(it, onStory) }
    }
}

@Composable fun Following(onStory: (Story) -> Unit, modifier: Modifier = Modifier) { LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp), contentPadding = PaddingValues(top = 20.dp, bottom = 24.dp)) { item { Header("Following", "Your interests. A broader point of view.") }; item { Text("Your topics", fontWeight = FontWeight.Bold, fontSize = 18.sp) }; item { Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) { listOf("World", "Politics").forEach { AssistChip(onClick = {}, label = { Text(it) }) } } }; items(stories.filter { it.topic == "World" || it.topic == "Politics" }) { StoryCard(it, onStory) } } }

@Composable fun StoryCard(story: Story, onClick: (Story) -> Unit, featured: Boolean = false) { Column(Modifier.fillMaxWidth().liquidGlass().clickable { onClick(story) }.padding(15.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { StoryImage(story, if (featured) 190 else 90); Text(if (story.left < 10 || story.right < 10) "◐ Blindspot" else "● Balanced coverage", fontSize = 12.sp, color = Secondary); Text(story.title, fontSize = if (featured) 24.sp else 19.sp, fontWeight = FontWeight.Bold, color = Ink); if (featured) Text(story.summary, color = Secondary, lineHeight = 20.sp); BiasBar(story); Text("${story.time}  ·  ${story.sources} sources", color = Secondary, fontSize = 12.sp) } }

@Composable fun StoryImage(story: Story, height: Int) { Box(Modifier.fillMaxWidth().height(height.dp).clip(RoundedCornerShape(9.dp)).background(Brush.linearGradient(story.colors)), contentAlignment = Alignment.Center) { Icon(Icons.Default.Cloud, null, Modifier.size(56.dp), tint = Color.White.copy(alpha = .72f)) } }

@Composable fun BiasBar(story: Story) { Row(Modifier.fillMaxWidth().height(7.dp).clip(RoundedCornerShape(5.dp))) { Box(Modifier.weight(story.left.toFloat()).fillMaxHeight().background(Left)); Box(Modifier.weight(story.center.toFloat()).fillMaxHeight().background(Center)); Box(Modifier.weight(story.right.toFloat()).fillMaxHeight().background(Right)) } }

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun StoryDetail(story: Story, onBack: () -> Unit) { Scaffold(topBar = { TopAppBar(title = { Text("Story") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, null) } }, actions = { IconButton(onClick = {}) { Icon(Icons.Default.BookmarkBorder, null) }; IconButton(onClick = {}) { Icon(Icons.Default.Share, null) } }) }) { padding -> LazyColumn(Modifier.padding(padding).padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(18.dp), contentPadding = PaddingValues(bottom = 24.dp)) { item { StoryImage(story, 230) }; item { Text(story.title, fontSize = 39.sp, fontWeight = FontWeight.Black, color = Ink) }; item { Text(story.summary, fontSize = 18.sp, color = Secondary, lineHeight = 26.sp) }; item { Text("Coverage", fontWeight = FontWeight.Bold, fontSize = 18.sp) }; item { BiasBar(story) }; item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Metric("Coverage", "${story.sources} sources", Modifier.weight(1f)); Metric("Bias", "Balanced", Modifier.weight(1f)) } }; item { Text("Where sources agree", fontSize = 28.sp, fontWeight = FontWeight.Black) }; item { Text(story.title + ". " + story.summary, lineHeight = 24.sp) }; item { Text("Where sources disagree", fontSize = 28.sp, fontWeight = FontWeight.Black) }; item { Text("Coverage differs on responsibility, consequences and the path forward. Read the original reporting for the complete picture.", lineHeight = 24.sp) } } } }

@Composable fun Metric(title: String, value: String, modifier: Modifier = Modifier) { Column(modifier.clip(RoundedCornerShape(12.dp)).background(Color(0xFFF5F5F5)).padding(14.dp)) { Text(title, color = Secondary); Text(value, fontWeight = FontWeight.Medium) } }

@Composable
fun GlassSettingsDialog(opacity: Float, onOpacityChange: (Float) -> Unit, radius: Float, onRadiusChange: (Float) -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("Done") } },
        title = { Text("Liquid glass") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Tune the floating navigation and story cards.", color = Secondary, fontSize = 12.sp)
                Text("Opacity  ${String.format("%.2f", opacity)}", fontSize = 12.sp)
                Slider(value = opacity, onValueChange = onOpacityChange, valueRange = 0.25f..0.95f)
                Text("Corner radius  ${radius.toInt()}", fontSize = 12.sp)
                Slider(value = radius, onValueChange = onRadiusChange, valueRange = 14f..38f)
            }
        }
    )
}

