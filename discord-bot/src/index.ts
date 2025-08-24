import { Client, GatewayIntentBits, Partials, Collection, Message, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle } from 'discord.js';
import { config } from 'dotenv';
import winston from 'winston';
import axios from 'axios';
import crypto from 'crypto';

// Load environment variables
config();

// Configure logging
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'device-notifier-bot' },
    transports: [
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' }),
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

// Bot configuration
const BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;
const ALLOWED_USERS = process.env.ALLOWED_USERS?.split(',') || [];
const ALLOWED_ROLES = process.env.ALLOWED_ROLES?.split(',') || [];
const HMAC_SECRET = process.env.HMAC_SECRET || 'default-secret-change-in-production';

if (!BOT_TOKEN) {
    logger.error('DISCORD_BOT_TOKEN is required');
    process.exit(1);
}

// Create Discord client
const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,
        GatewayIntentBits.GuildMembers
    ],
    partials: [Partials.Channel, Partials.Message, Partials.User]
});

// Command registry
const commands = new Collection<string, Command>();

interface Command {
    name: string;
    description: string;
    usage: string;
    execute: (message: Message, args: string[]) => Promise<void>;
    requiresAuth: boolean;
}

// Command implementations
const lockCommand: Command = {
    name: 'lock',
    description: 'Lock the device screen',
    usage: '!lock [device_alias]',
    requiresAuth: true,
    execute: async (message: Message, args: string[]) => {
        const deviceAlias = args[0] || 'default';
        
        try {
            const command = createSignedCommand('lock', deviceAlias);
            const response = await sendCommandToDevice(deviceAlias, command);
            
            const embed = new EmbedBuilder()
                .setTitle('🔒 Screen Lock Command')
                .setDescription(`Command sent to device: ${deviceAlias}`)
                .addFields(
                    { name: 'Status', value: response.success ? '✅ Success' : '❌ Failed', inline: true },
                    { name: 'Message', value: response.message, inline: true },
                    { name: 'Timestamp', value: new Date().toISOString(), inline: true }
                )
                .setColor(response.success ? 0x00ff00 : 0xff0000);
            
            await message.reply({ embeds: [embed] });
            
        } catch (error) {
            logger.error('Lock command failed:', error);
            await message.reply('❌ Failed to execute lock command');
        }
    }
};

const statusCommand: Command = {
    name: 'status',
    description: 'Get device status',
    usage: '!status [device_alias]',
    requiresAuth: true,
    execute: async (message: Message, args: string[]) => {
        const deviceAlias = args[0] || 'default';
        
        try {
            const command = createSignedCommand('status', deviceAlias);
            const response = await sendCommandToDevice(deviceAlias, command);
            
            if (response.success) {
                const statusData = JSON.parse(response.message);
                const embed = new EmbedBuilder()
                    .setTitle('📊 Device Status')
                    .setDescription(`Device: ${deviceAlias}`)
                    .addFields(
                        { name: 'Platform', value: statusData.platform || 'Unknown', inline: true },
                        { name: 'Version', value: statusData.version || 'Unknown', inline: true },
                        { name: 'Discord Connected', value: statusData.discord_connected ? '✅ Yes' : '❌ No', inline: true },
                        { name: 'Last Heartbeat', value: statusData.last_heartbeat || 'Unknown', inline: true }
                    )
                    .setColor(0x0088ff);
                
                await message.reply({ embeds: [embed] });
            } else {
                await message.reply(`❌ Failed to get status: ${response.message}`);
            }
            
        } catch (error) {
            logger.error('Status command failed:', error);
            await message.reply('❌ Failed to get device status');
        }
    }
};

const pingCommand: Command = {
    name: 'ping',
    description: 'Test device connectivity',
    usage: '!ping [device_alias]',
    requiresAuth: true,
    execute: async (message: Message, args: string[]) => {
        const deviceAlias = args[0] || 'default';
        
        try {
            const command = createSignedCommand('ping', deviceAlias);
            const response = await sendCommandToDevice(deviceAlias, command);
            
            const embed = new EmbedBuilder()
                .setTitle('🏓 Ping Test')
                .setDescription(`Device: ${deviceAlias}`)
                .addFields(
                    { name: 'Status', value: response.success ? '✅ Online' : '❌ Offline', inline: true },
                    { name: 'Response', value: response.message, inline: true },
                    { name: 'Latency', value: '~100ms', inline: true }
                )
                .setColor(response.success ? 0x00ff00 : 0xff0000);
            
            await message.reply({ embeds: [embed] });
            
        } catch (error) {
            logger.error('Ping command failed:', error);
            await message.reply('❌ Failed to ping device');
        }
    }
};

const logoutCommand: Command = {
    name: 'logout',
    description: 'Logout current user (requires confirmation)',
    usage: '!logout [device_alias]',
    requiresAuth: true,
    execute: async (message: Message, args: string[]) => {
        const deviceAlias = args[0] || 'default';
        
        const embed = new EmbedBuilder()
            .setTitle('⚠️ Logout Confirmation Required')
            .setDescription(`Are you sure you want to logout user from device: ${deviceAlias}?`)
            .setColor(0xff8800);
        
        const row = new ActionRowBuilder<ButtonBuilder>()
            .addComponents(
                new ButtonBuilder()
                    .setCustomId(`confirm_logout_${deviceAlias}`)
                    .setLabel('Confirm Logout')
                    .setStyle(ButtonStyle.Danger),
                new ButtonBuilder()
                    .setCustomId('cancel_logout')
                    .setLabel('Cancel')
                    .setStyle(ButtonStyle.Secondary)
            );
        
        await message.reply({ embeds: [embed], components: [row] });
    }
};

const helpCommand: Command = {
    name: 'help',
    description: 'Show available commands',
    usage: '!help',
    requiresAuth: false,
    execute: async (message: Message) => {
        const embed = new EmbedBuilder()
            .setTitle('🤖 Device Notifier Bot Commands')
            .setDescription('Available commands for device management:')
            .addFields(
                { name: '!lock [device]', value: 'Lock device screen', inline: true },
                { name: '!status [device]', value: 'Get device status', inline: true },
                { name: '!ping [device]', value: 'Test device connectivity', inline: true },
                { name: '!logout [device]', value: 'Logout current user', inline: true },
                { name: '!help', value: 'Show this help message', inline: true }
            )
            .setColor(0x0088ff);
        
        await message.reply({ embeds: [embed] });
    }
};

// Register commands
commands.set('lock', lockCommand);
commands.set('status', statusCommand);
commands.set('ping', pingCommand);
commands.set('logout', logoutCommand);
commands.set('help', helpCommand);

// Bot event handlers
client.once('ready', () => {
    logger.info(`Bot logged in as ${client.user?.tag}`);
    logger.info(`Serving ${client.guilds.cache.size} guilds`);
});

client.on('messageCreate', async (message: Message) => {
    if (message.author.bot) return;
    if (!message.content.startsWith('!')) return;
    
    const args = message.content.slice(1).trim().split(/ +/);
    const commandName = args.shift()?.toLowerCase();
    
    if (!commandName || !commands.has(commandName)) return;
    
    const command = commands.get(commandName)!;
    
    // Check authorization
    if (command.requiresAuth && !isAuthorized(message)) {
        await message.reply('❌ You are not authorized to use this command');
        return;
    }
    
    try {
        await command.execute(message, args);
    } catch (error) {
        logger.error(`Error executing command ${commandName}:`, error);
        await message.reply('❌ An error occurred while executing the command');
    }
});

// Button interaction handler
client.on('interactionCreate', async (interaction) => {
    if (!interaction.isButton()) return;
    
    if (interaction.customId.startsWith('confirm_logout_')) {
        const deviceAlias = interaction.customId.replace('confirm_logout_', '');
        
        try {
            const command = createSignedCommand('logout', deviceAlias);
            const response = await sendCommandToDevice(deviceAlias, command);
            
            const embed = new EmbedBuilder()
                .setTitle('👋 Logout Command Executed')
                .setDescription(`Device: ${deviceAlias}`)
                .addFields(
                    { name: 'Status', value: response.success ? '✅ Success' : '❌ Failed', inline: true },
                    { name: 'Message', value: response.message, inline: true }
                )
                .setColor(response.success ? 0x00ff00 : 0xff0000);
            
            await interaction.reply({ embeds: [embed] });
            
        } catch (error) {
            logger.error('Logout command failed:', error);
            await interaction.reply('❌ Failed to execute logout command');
        }
    } else if (interaction.customId === 'cancel_logout') {
        await interaction.reply('❌ Logout cancelled');
    }
});

// Authorization check
function isAuthorized(message: Message): boolean {
    const userId = message.author.id;
    const member = message.member;
    
    // Check if user is in allowed users list
    if (ALLOWED_USERS.includes(userId)) {
        return true;
    }
    
    // Check if user has allowed roles
    if (member && ALLOWED_ROLES.some(roleId => member.roles.cache.has(roleId))) {
        return true;
    }
    
    return false;
}

// Create signed command
function createSignedCommand(commandType: string, deviceAlias: string): any {
    const timestamp = Date.now();
    const commandId = crypto.randomUUID();
    
    const payload = `${commandId}${deviceAlias}${timestamp}`;
    const signature = crypto.createHmac('sha256', HMAC_SECRET)
        .update(payload)
        .digest('base64');
    
    return {
        command: commandType,
        command_id: commandId,
        authorized_user: deviceAlias,
        timestamp: new Date(timestamp).toISOString(),
        signature: signature
    };
}

// Send command to device (placeholder implementation)
async function sendCommandToDevice(deviceAlias: string, command: any): Promise<any> {
    // In a real implementation, this would send the command to the actual device
    // For now, we'll simulate a response
    
    logger.info(`Sending command to device ${deviceAlias}:`, command);
    
    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Simulate response based on command type
    switch (command.command) {
        case 'lock':
            return { success: true, message: 'Screen locked successfully' };
        case 'status':
            return {
                success: true,
                message: JSON.stringify({
                    platform: 'Windows',
                    version: '1.0.0',
                    discord_connected: true,
                    last_heartbeat: new Date().toISOString()
                })
            };
        case 'ping':
            return { success: true, message: 'Pong! Device is responsive' };
        case 'logout':
            return { success: true, message: 'User logged out successfully' };
        default:
            return { success: false, message: 'Unknown command' };
    }
}

// Error handling
process.on('unhandledRejection', (error) => {
    logger.error('Unhandled promise rejection:', error);
});

process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception:', error);
    process.exit(1);
});

// Start the bot
client.login(BOT_TOKEN).catch((error) => {
    logger.error('Failed to login:', error);
    process.exit(1);
});
